class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
    @processed_actions = []
    @sent_blob_ids = [] # Controla quais blobs já foram enviados
  end

  def perform
    # Log para debug das ações
    Rails.logger.info "ActionService: Processando #{@rule.actions.length} ações para a regra ID=#{@rule.id}"
    @rule.actions.each_with_index do |action, idx|
      Rails.logger.info "ActionService: Ação[#{idx}] = #{action['action_name']} com params=#{action['action_params']}"
    end

    # Log dos arquivos disponíveis na regra
    if @rule.files.attached?
      Rails.logger.info "ActionService: Regra possui #{@rule.files.count} arquivos anexados"
      @rule.files.each_with_index do |file, idx|
        Rails.logger.info "ActionService: Arquivo[#{idx}] = ID:#{file.id}, nome:#{file.filename}, blob_id:#{file.blob_id}"
      end
    end

    # Criar mapeamento de ações para processamento mais organizado
    action_mapping = {}
    # Primeiro coletamos todas as ações em um mapa para referência futura
    @rule.actions.each_with_index do |action, index|
      action = action.with_indifferent_access
      action_mapping[index] = {
        action_name: action[:action_name],
        action_params: action[:action_params],
        processed: false
      }
    end

    # Agrupar mensagens e anexos para envio conjunto
    message_groups = []
    current_group = { attachments: [], message: nil, indices: [] }

    # Percorrer as ações em ordem para formar grupos de mensagem + anexos
    @rule.actions.each_with_index do |action, index|
      action = action.with_indifferent_access

      if action[:action_name] == 'send_attachment'
        if current_group[:message].nil?
          # Se ainda não tem mensagem, adiciona anexo ao grupo atual
          current_group[:attachments].push(action[:action_params].first)
          current_group[:indices].push(index)
        else
          # Se já tem mensagem, fecha o grupo atual e inicia um novo com este anexo
          message_groups.push(current_group) if current_group[:message]
          current_group = { attachments: [action[:action_params].first], message: nil, indices: [index] }
        end
      elsif action[:action_name] == 'send_message'
        if current_group[:message].nil?
          # Se não tem mensagem no grupo atual, adiciona
          current_group[:message] = action[:action_params].first
          current_group[:indices].push(index)

          # Se já tem anexos neste grupo, está completo
          if current_group[:attachments].any?
            message_groups.push(current_group)
            current_group = { attachments: [], message: nil, indices: [] }
          end
        else
          # Se já tem mensagem, fecha o grupo e inicia um novo com esta mensagem
          message_groups.push(current_group)
          current_group = { attachments: [], message: action[:action_params].first, indices: [index] }
        end
      else
        # Para outras ações, processamos individualmente depois
        action_mapping[index][:processed] = false
      end
    end

    # Adicionar o último grupo se não estiver vazio
    message_groups.push(current_group) if current_group[:message] || current_group[:attachments].any?

    # Processar os grupos de mensagens com anexos
    message_groups.each do |group|
      process_message_group(group, action_mapping)
    end

    # Processar outras ações que não foram incluídas em nenhum grupo
    process_remaining_actions(action_mapping)

    Rails.logger.info "ActionService: Finalizado processamento de ações, processados=#{@processed_actions.inspect}, blobs enviados=#{@sent_blob_ids.inspect}"
  ensure
    Current.reset
  end

  private

  def process_message_group(group, action_mapping)
    Rails.logger.info "ActionService: Processando grupo com mensagem='#{group[:message]}' e anexos=#{group[:attachments].inspect}"

    # Marque todas as ações deste grupo como processadas
    group[:indices].each do |index|
      action_mapping[index][:processed] = true
      @processed_actions << index
    end

    # Só enviar se tiver mensagem e/ou anexos
    if group[:message].present? || group[:attachments].present?
      if group[:attachments].present? && group[:message].present?
        send_message_with_attachments(group[:message], group[:attachments])
      elsif group[:attachments].present?
        send_attachments_only(group[:attachments])
      elsif group[:message].present?
        send_message([group[:message]])
      end
    end
  end

  def process_remaining_actions(action_mapping)
    action_mapping.each do |index, action_data|
      next if action_data[:processed]

      begin
        send(action_data[:action_name], action_data[:action_params])
        @processed_actions << index
      rescue StandardError => e
        Rails.logger.error "ActionService: ERRO ao processar ação #{action_data[:action_name]}: #{e.message}\n#{e.backtrace.join("\n")}"
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  end

  def send_message_with_attachments(message_content, blob_ids)
    return if conversation_a_tweet?
    return unless @rule.files.attached?

    Rails.logger.info "ActionService: Enviando mensagem '#{message_content}' com anexos #{blob_ids.inspect}"

    # Obter arquivos através dos blob_ids
    attachments = []
    blob_ids.each do |blob_id|
      # Encontrar o Attachment correto baseado no blob_id
      attachment = @rule.files.find_by(blob_id: blob_id)
      if attachment
        attachments << attachment
        Rails.logger.info "ActionService: Anexo encontrado para blob_id=#{blob_id}, filename=#{attachment.filename}"
      else
        Rails.logger.warn "ActionService: Anexo não encontrado para blob_id=#{blob_id}"
      end
    end

    return if attachments.blank?

    # Usar a mensagem para criar um novo registro
    message = @conversation.messages.build(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :outgoing,
      content: message_content,
      content_attributes: { automation_rule_id: @rule.id }
    )

    # Anexar os arquivos diretamente ao invés de usar o MessageBuilder
    attachments.each do |file_attachment|
      message.attachments.new(
        account_id: @conversation.account_id,
        file_type: file_attachment.content_type =~ /image/ ? :image : :file
      ).file.attach(file_attachment.blob)
    end

    message.save!
    Rails.logger.info "ActionService: Mensagem criada ID=#{message.id} com #{message.attachments.count} anexos"
  end

  def send_attachments_only(blob_ids)
    Rails.logger.info "ActionService: Enviando somente anexos #{blob_ids.inspect}"
    send_message_with_attachments('', blob_ids)
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_private_note(message)
    return if conversation_a_tweet?
    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
    end
  end

  # Método mantido para compatibilidade, redirecionando para o novo método
  def send_attachment_with_message(blob_ids, message_content)
    send_message_with_attachments(message_content, blob_ids)
  end

  # Método mantido para compatibilidade, redirecionando para o novo método
  def send_attachment(blob_ids)
    send_attachments_only(blob_ids)
  end
end
