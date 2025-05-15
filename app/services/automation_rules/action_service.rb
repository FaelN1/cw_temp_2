class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    @actions_to_perform = rule.actions || []
    @processed_actions = []
    @sent_blob_ids = [] # Controla quais blobs já foram enviados nesta execução
  end

  def perform
    Current.account = @account
    Current.user = @rule.user || User.system_bot # Garante que Current.user esteja definido

    Rails.logger.info "ActionService: Processando #{@actions_to_perform.count} ações para a regra ID=#{@rule.id}"

    i = 0
    while i < @actions_to_perform.length
      current_action = @actions_to_perform[i]
      action_name = current_action['action_name']
      action_params = current_action['action_params']

      Rails.logger.info "ActionService: Executando ação '#{action_name}' (índice #{i}) com params: #{action_params.inspect}"

      case action_name
      when 'send_message'
        message_content = action_params.is_a?(Array) ? action_params[0] : nil
        send_message(message_content) if message_content.present?
        @processed_actions << current_action
        i += 1

      when 'send_attachment'
        blob_ids_param = action_params
        actual_blob_ids = []

        if blob_ids_param.is_a?(Array)
          blob_ids_param.each do |param_item|
            if param_item.is_a?(Hash) && param_item['blob_id']
              actual_blob_ids << param_item['blob_id']
            elsif param_item.is_a?(String) || param_item.is_a?(Integer)
              actual_blob_ids << param_item
            end
          end
        end
        actual_blob_ids.compact!
        actual_blob_ids.uniq!

        if actual_blob_ids.empty?
          Rails.logger.warn "ActionService: Ação 'send_attachment' sem blob_ids válidos. Params: #{action_params.inspect}"
          @processed_actions << current_action
          i += 1
          next
        end

        caption = nil
        # Verifica se a próxima ação é 'send_message' para ser a legenda
        if (i + 1) < @actions_to_perform.length && @actions_to_perform[i + 1]['action_name'] == 'send_message'
          caption_text_array = @actions_to_perform[i + 1]['action_params']
          caption = caption_text_array[0] if caption_text_array.is_a?(Array) && caption_text_array[0].present?
        end

        if caption
          Rails.logger.info "ActionService: Enviando anexo com legenda: '#{caption}'"
          # Usar os blob_ids que ainda não foram enviados nesta execução
          ids_to_send_now = actual_blob_ids.reject { |id| @sent_blob_ids.include?(id) }
          send_message_with_attachments(caption, ids_to_send_now) unless ids_to_send_now.empty?

          @processed_actions << current_action # Ação do anexo
          @processed_actions << @actions_to_perform[i + 1] # Ação da legenda
          @sent_blob_ids.concat(ids_to_send_now).uniq!
          i += 2 # Pula o anexo e a legenda
        else
          Rails.logger.info "ActionService: Enviando anexo sem legenda."
          ids_to_send_now = actual_blob_ids.reject { |id| @sent_blob_ids.include?(id) }
          send_attachments_only(ids_to_send_now) unless ids_to_send_now.empty?

          @processed_actions << current_action # Ação do anexo
          @sent_blob_ids.concat(ids_to_send_now).uniq!
          i += 1 # Pula apenas o anexo
        end

      when 'add_label_to_conversation'
        add_labels_to_conversation(action_params) if action_params.present?
        @processed_actions << current_action
        i += 1
      when 'remove_label_from_conversation'
        remove_labels_from_conversation(action_params) if action_params.present?
        @processed_actions << current_action
        i += 1
      when 'assign_agent'
        agent_id = action_params[0].is_a?(Hash) ? action_params[0]['id'] : action_params[0]
        assign_agent(agent_id) if agent_id.present?
        @processed_actions << current_action
        i += 1
      when 'assign_team'
        team_id = action_params[0].is_a?(Hash) ? action_params[0]['id'] : action_params[0]
        assign_team(team_id) if team_id.present?
        @processed_actions << current_action
        i += 1
      when 'send_email_to_team'
        email_param_obj = action_params[0] if action_params.is_a?(Array)
        if email_param_obj.is_a?(Hash) && email_param_obj['team_id'] && email_param_obj['message']
          send_email_to_team(team_ids: [email_param_obj['team_id']], message: email_param_obj['message'])
        else
          Rails.logger.warn "ActionService: Parâmetros inválidos para send_email_to_team: #{action_params.inspect}"
        end
        @processed_actions << current_action
        i += 1
      when 'send_webhook_event'
        webhook_url = action_params[0] if action_params.is_a?(Array)
        send_webhook_event(webhook_url) if webhook_url.present?
        @processed_actions << current_action
        i += 1
      when 'mute_conversation'
        mute_conversation
        @processed_actions << current_action
        i += 1
      when 'snooze_conversation'
        snooze_duration_key = action_params[0] if action_params.is_a?(Array)
        mark_as_snoozed(snooze_duration_key) if snooze_duration_key.present?
        @processed_actions << current_action
        i += 1
      when 'resolve_conversation'
        resolve_conversation
        @processed_actions << current_action
        i += 1
      when 'reopen_conversation'
        reopen_conversation
        @processed_actions << current_action
        i += 1
      when 'change_priority'
        priority = action_params[0] if action_params.is_a?(Array)
        change_priority(priority) if priority.present?
        @processed_actions << current_action
        i += 1
      when 'send_private_note'
        note_content = action_params.is_a?(Array) ? action_params[0] : nil
        send_private_note(note_content) if note_content.present?
        @processed_actions << current_action
        i += 1
      else
        Rails.logger.warn "ActionService: Ação desconhecida ou não explicitamente tratada no loop principal: '#{action_name}'. Pulando."
        @processed_actions << current_action # Marca como processada para fins de log
        i += 1
      end
    end

    Rails.logger.info "ActionService: Finalizado processamento de ações. Ações processadas: #{@processed_actions.count}. IDs de blob enviados nesta execução: #{@sent_blob_ids.inspect}"
  ensure
    Current.reset
  end

  private

  # Modificado para não depender de @rule.files e usar os blob_ids fornecidos
  def send_message_with_attachments(message_content, blob_ids_for_this_message)
    return if conversation_a_tweet?
    return if blob_ids_for_this_message.blank?

    attached_files = files_to_attach(blob_ids_for_this_message)
    if attached_files.any?
      create_messages_with_attachments(message_content, attached_files)
    elsif message_content.present?
      # Se não houver arquivos válidos mas houver legenda, enviar apenas a legenda como mensagem normal.
      # No entanto, a lógica do perform já consumiu a ação de legenda, então isso não deve ocorrer
      # a menos que files_to_attach retorne vazio para IDs válidos.
      Rails.logger.warn "ActionService: Nenhum arquivo válido encontrado para blob_ids: #{blob_ids_for_this_message.inspect} ao tentar enviar com legenda. Legenda: '#{message_content}'"
      # Considerar se a legenda deve ser enviada como mensagem separada se os arquivos falharem.
      # Por ora, se os arquivos falham, a mensagem com anexo não é criada.
    end
  end

  # Modificado para não depender de @rule.files e usar os blob_ids fornecidos
  def send_attachments_only(blob_ids_for_this_message)
    return if conversation_a_tweet?
    return if blob_ids_for_this_message.blank?

    attached_files = files_to_attach(blob_ids_for_this_message)
    if attached_files.any?
      create_messages_with_attachments(nil, attached_files) # nil para content
    else
      Rails.logger.warn "ActionService: Nenhum arquivo válido encontrado para blob_ids: #{blob_ids_for_this_message.inspect} ao tentar enviar apenas anexos."
    end
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
