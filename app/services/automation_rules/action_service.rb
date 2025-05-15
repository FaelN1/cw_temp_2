require 'set' # Necessário para 'Set'

class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
  end

  def perform
    actions = @rule.actions.map(&:with_indifferent_access)
    processed_action_indices = Set.new # Para rastrear ações já tratadas

    actions.each_with_index do |action, index|
      next if processed_action_indices.include?(index) # Pula se já foi processada

      # Verifica se a ação deve ser pulada se a conversa for um tweet
      is_restricted_by_tweet = conversation_a_tweet? &&
                               ['send_message', 'send_attachment', 'send_private_note'].include?(action[:action_name])
      next if is_restricted_by_tweet

      @conversation.reload

      begin
        case action[:action_name]
        when 'send_attachment'
          # Log para depurar os action_params recebidos para esta ação de anexo
          Rails.logger.debug "AutomationRules::ActionService: Processing send_attachment action at index #{index} with action_params: #{action[:action_params].inspect} for rule #{@rule.id}"

          # Garante que cada iteração trabalhe com uma cópia independente dos parâmetros
          attachment_action_params = action[:action_params].is_a?(Array) ? action[:action_params].dup : action[:action_params]
          caption_to_use = nil
          caption_action_original_index = -1
          caption_action_data = nil # Para armazenar o hash da ação de legenda para atributos

          potential_caption_index = index + 1
          # Verifica se a próxima ação é 'send_message' para usar como legenda
          if potential_caption_index < actions.length &&
             actions[potential_caption_index][:action_name] == 'send_message' &&
             !processed_action_indices.include?(potential_caption_index)

            # Uma mensagem combinada (anexo com legenda de texto) só é formada se não for um tweet.
            unless conversation_a_tweet?
              caption_action_data = actions[potential_caption_index]
              message_content_array = caption_action_data[:action_params]
              caption_to_use = message_content_array[0] if message_content_array.is_a?(Array)
              caption_action_original_index = potential_caption_index
            end
          end

          if caption_to_use # Implica !conversation_a_tweet? devido à verificação acima
            actual_blob_ids = Array(attachment_action_params).flatten.compact_blank
            if actual_blob_ids.any? && @rule.files.attached?
              fetched_blobs = ActiveStorage::Blob.where(id: actual_blob_ids).to_a
              unless fetched_blobs.blank?
                caption_attributes = caption_action_data[:content_attributes] if caption_action_data
                combined_params = {
                  content: caption_to_use,
                  private: false,
                  attachments: fetched_blobs,
                  content_attributes: caption_attributes || { automation_rule_id: @rule.id }
                }
                Messages::MessageBuilder.new(nil, @conversation, combined_params).perform
                processed_action_indices.add(caption_action_original_index) # Marca a legenda como usada
                processed_action_indices.add(index) # Marca o anexo como usado
              else
                Rails.logger.warn "AutomationRules::ActionService: Blobs buscados estão vazios para mensagem combinada. Rule: #{@rule.id}, AttachActionIndex: #{index}, CaptionActionIndex: #{caption_action_original_index}"
                processed_action_indices.add(index) # Marca a ação de anexo como tratada (tentativa falhou)
                processed_action_indices.add(caption_action_original_index) if caption_action_original_index != -1 # Marca a legenda como tratada
              end
            else
              Rails.logger.warn "AutomationRules::ActionService: Sem actual_blob_ids ou @rule.files.attached? é falso para mensagem combinada. Rule: #{@rule.id}, AttachActionIndex: #{index}"
              processed_action_indices.add(index)
              processed_action_indices.add(caption_action_original_index) if caption_action_original_index != -1
            end
          else
            # Nenhuma legenda encontrada, ou é um contexto de tweet onde mensagens combinadas não são enviadas.
            # Envia o anexo sozinho usando o método privado.
            # O método privado send_attachment tem suas próprias verificações (tweet, files.attached, blobs.blank).
            send_attachment(attachment_action_params)
            processed_action_indices.add(index) # Marca a ação de anexo como tratada
          end

        when 'send_message'
          # Esta ação é processada aqui se não foi usada como legenda por um 'send_attachment' anterior.
          # A verificação 'is_restricted_by_tweet' no início do loop garante que isso não seja chamado para tweets.
          Rails.logger.debug "AutomationRules::ActionService: Processing send_message action at index #{index} with action_params: #{action[:action_params].inspect} for rule #{@rule.id}"
          send_message(action[:action_params])
          processed_action_indices.add(index)

        when 'send_webhook_event'
          send_webhook_event(action[:action_params])
          processed_action_indices.add(index)

        when 'send_private_note'
          # A verificação 'is_restricted_by_tweet' no início do loop garante que isso não seja chamado para tweets.
          send_private_note(action[:action_params])
          processed_action_indices.add(index)

        when 'send_email_to_team'
          send_email_to_team(action[:action_params])
          processed_action_indices.add(index)

        else
          # Trata outras ações despachadas dinamicamente
          if respond_to?(action[:action_name], true)
            send(action[:action_name], action[:action_params])
          else
            Rails.logger.warn "Unknown action: #{action[:action_name]} for rule #{@rule.id}, account #{@account.id}"
          end
          # Marca como processada mesmo se desconhecida ou falhou em responder, para evitar reprocessamento neste loop.
          processed_action_indices.add(index)
        end
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account, custom_attributes: { rule_id: @rule.id, action_name: action[:action_name], action_params: action[:action_params] }).capture_exception
        # Marca como processada para evitar tentar novamente a mesma ação falha dentro desta chamada de perform
        processed_action_indices.add(index) unless processed_action_indices.include?(index)
      end
    end
  ensure
    Current.reset
  end

  private

  def send_attachment(blob_ids_param)
    return if conversation_a_tweet?
    return unless @rule.files.attached?

    actual_blob_ids = Array(blob_ids_param).flatten.compact_blank
    return if actual_blob_ids.blank?

    blobs = ActiveStorage::Blob.where(id: actual_blob_ids)
    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url_param)
    webhook_url = webhook_url_param.is_a?(Array) ? webhook_url_param[0] : webhook_url_param
    return if webhook_url.blank?

    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url, payload)
  end

  def send_message(message_param)
    return if conversation_a_tweet?

    content = message_param.is_a?(Array) ? message_param[0] : message_param
    # Permite string vazia, mas não outros tipos blank se não for string.
    return if content.nil? || (content.respond_to?(:empty?) && content.empty? && !content.is_a?(String))


    params = { content: content, private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_private_note(message_param)
    return if conversation_a_tweet?

    content = message_param.is_a?(Array) ? message_param[0] : message_param
    return if content.nil? || (content.respond_to?(:empty?) && content.empty? && !content.is_a?(String))

    params = { content: content, private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_email_to_team(params_param)
    param_data = params_param.is_a?(Array) ? params_param[0] : params_param
    return unless param_data.is_a?(Hash)

    team_ids = param_data[:team_ids]
    message_content = param_data[:message]

    return if Array(team_ids).empty? || message_content.blank? # Garante que team_ids seja tratado como array para .empty?

    teams = Team.where(id: team_ids)
    return if teams.empty?

    teams.each do |team|
      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, message_content)&.deliver_now
    end
  end
end
