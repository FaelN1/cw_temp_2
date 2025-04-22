module Whatsapp
  class OneoffWhatsappCampaignService
    pattr_initialize [:campaign!]

    def perform
      # Verifica se é um tipo de canal suportado (WhatsApp ou API)
      unless ['Channel::Whatsapp', 'Channel::Api'].include?(campaign.inbox.channel_type)
        raise "Campanha inválida #{campaign.id}: canal #{campaign.inbox.channel_type} não suportado (apenas WhatsApp e API)"
      end

      # Para canais API, aceitamos qualquer tipo de campanha
      # Para canais WhatsApp, verificamos se é one_off
      if campaign.inbox.channel_type == 'Channel::Whatsapp' && !campaign.one_off?
        raise "Campanha inválida #{campaign.id}: não é do tipo one_off"
      end

      # Verifica se a campanha já foi concluída
      if campaign.completed?
        raise 'Campanha já concluída'
      end

      # LOGS DETALHADOS PARA DEPURAÇÃO
      Rails.logger.info "============= DEPURAÇÃO DA CAMPANHA #{campaign.id} ============="
      Rails.logger.info "Mensagem: #{campaign.message.inspect}"
      Rails.logger.info "template_params: #{campaign.template_params.inspect}"
      Rails.logger.info "template_params class: #{campaign.template_params.class}"

      # Verificar se a campanha tem template_params ou mensagem
      has_template = false
      if campaign.template_params.present?
        has_template = true
        Rails.logger.info "has_template: #{has_template}, template_params: #{campaign.template_params.inspect}"
      end

      has_message = campaign.message.present?
      Rails.logger.info "has_message: #{has_message}"

      # Validar se há ao menos uma forma válida de mensagem
      unless has_template || has_message
        Rails.logger.error "ERRO DE VALIDAÇÃO: Campanha #{campaign.id} sem mensagem (#{has_message}) e sem template (#{has_template})"
        raise 'Campanha sem mensagem ou template'
      end

      # Marca a campanha como concluída para que outros jobs não a processem
      # Usamos update_column para evitar validações neste momento
      campaign.update_column(:campaign_status, 'completed')
      Rails.logger.info "Campanha #{campaign.id} marcada como concluída"

      # Obtém as etiquetas da audiência
      audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
      Rails.logger.info "Ids das etiquetas na audiência: #{audience_label_ids.join(', ')}"

      audience_labels = campaign.account.labels.where(id: audience_label_ids).pluck(:title)
      Rails.logger.info "Etiquetas encontradas: #{audience_labels.join(', ')}"

      process_audience(audience_labels)
    end

    private

    delegate :inbox, to: :campaign
    delegate :channel, to: :inbox

    def process_audience(audience_labels)
      # Primeiro, encontra as conversas com as etiquetas especificadas
      conversations_with_labels = campaign.account.conversations.tagged_with(audience_labels)
      Rails.logger.info "Encontradas #{conversations_with_labels.count} conversas com etiquetas: #{audience_labels.join(', ')}"

      # Extrair IDs dos contatos dessas conversas
      contact_ids = conversations_with_labels.pluck(:contact_id).uniq
      Rails.logger.info "Extraídos #{contact_ids.count} contatos únicos"

      # Buscar os objetos de contato completos
      contacts = campaign.account.contacts.where(id: contact_ids)
      Rails.logger.info "Processando #{contacts.count} contatos para etiquetas: #{audience_labels.join(', ')}"

      # Log detalhado dos contatos encontrados
      if contacts.count > 0
        contacts_info = contacts.select(:id, :name, :email, :phone_number).map do |contact|
          {
            id: contact.id,
            name: contact.name,
            email: contact.email,
            phone: contact.phone_number
          }
        end
        Rails.logger.info "Detalhes dos contatos: #{contacts_info.to_json}"
      end

      success_count = 0
      failure_count = 0

      contacts.each do |contact|
        # Pula contatos sem número de telefone
        if contact.phone_number.blank?
          Rails.logger.warn "Contato #{contact.id} (#{contact.name}) não possui telefone. Pulando..."
          failure_count += 1
          next
        end

        begin
          # Verificar o tipo de canal - API sempre usa texto simples
          if campaign.inbox.channel_type == 'Channel::Api'
            send_text_message(contact)
          else
            # Para WhatsApp verificar se tem template_params
            if campaign.template_params.present?
              send_template_message(contact)
            else
              send_text_message(contact)
            end
          end

          success_count += 1
        rescue StandardError => e
          Rails.logger.error "Erro ao enviar mensagem para #{contact.phone_number}: #{e.message}"
          failure_count += 1
        end
      end

      Rails.logger.info "Campanha #{campaign.inbox.channel_type} #{campaign.id} concluída: enviados=#{success_count}, falhas=#{failure_count}"
    end

    def send_template_message(contact)
      contact_inbox = find_or_create_contact_inbox(contact)
      return unless contact_inbox

      conversation = find_or_create_conversation(contact_inbox)

      # Utilizar campaign.template_params diretamente
      template_params = campaign.template_params

      # Processar template_params se for uma string JSON
      if template_params.is_a?(String)
        template_params = JSON.parse(template_params) rescue {}
      end

      Rails.logger.info "Template params: #{template_params.inspect}"

      # Criar a mensagem com os parâmetros de template configurados diretamente no additional_attributes
      message = conversation.messages.create!(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: 'outgoing',
        content: template_params['name'] || '', # Nome do template como conteúdo
        sender: campaign.sender || campaign.inbox.account.agents.first,
        additional_attributes: {
          template_params: template_params,
          campaign_id: campaign.id
        }
      )

      Rails.logger.info "Template enviado para #{contact.phone_number}, mensagem ##{message.id}, template_params: #{template_params}"
      message
    end

    def send_text_message(contact)
      contact_inbox = find_or_create_contact_inbox(contact)
      return unless contact_inbox

      conversation = find_or_create_conversation(contact_inbox)

      # Criar a mensagem diretamente para evitar problemas com o MessageBuilder
      message = conversation.messages.create!(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: 'outgoing',
        content: campaign.message,
        sender: campaign.sender || campaign.inbox.account.agents.first,
        additional_attributes: { campaign_id: campaign.id }
      )

      Rails.logger.info "Mensagem enviada para #{contact.phone_number}, mensagem ##{message.id}"
      message
    end

    def find_or_create_contact_inbox(contact)
      contact_inbox = contact.contact_inboxes.find_by(inbox_id: campaign.inbox_id)

      unless contact_inbox
        Rails.logger.info "Criando contact_inbox para contato #{contact.id} (#{contact.name}) na inbox #{campaign.inbox_id}"
        source_id = generate_source_id(contact)
        contact_inbox = ContactInbox.create!(
          contact: contact,
          inbox: campaign.inbox,
          source_id: source_id
        )
      end

      contact_inbox
    rescue StandardError => e
      Rails.logger.error "Erro ao criar contact_inbox para #{contact.id}: #{e.message}"
      nil
    end

    def find_or_create_conversation(contact_inbox)
      conversation = contact_inbox.conversations.last

      unless conversation
        Rails.logger.info "Criando conversa para contact_inbox #{contact_inbox.id}"
        conversation = ::Conversation.create!(
          account_id: campaign.account_id,
          inbox_id: campaign.inbox_id,
          contact_id: contact_inbox.contact_id,
          contact_inbox_id: contact_inbox.id,
          campaign_id: campaign.id
        )
      end

      conversation
    end

    def generate_source_id(contact)
      # Para WhatsApp, o source_id precisa ser um número puro (apenas dígitos)
      # Não podemos usar letras ou caracteres especiais
      if campaign.inbox.channel_type == 'Channel::Whatsapp'
        # Extrair apenas os dígitos do número de telefone
        phone_digits = contact.phone_number.gsub(/[^\d]/, '')
        return phone_digits
      else
        # Para outros canais, podemos usar um formato mais complexo
        phone_digits = contact.phone_number.gsub(/[^\d]/, '')
        return "#{phone_digits}#{rand(1000..9999)}"
      end
    end
  end
end
