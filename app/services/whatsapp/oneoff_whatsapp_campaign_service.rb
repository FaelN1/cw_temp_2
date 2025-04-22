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

      # Marca a campanha como concluída para que outros jobs não a processem
      campaign.completed!

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
            # Para outros canais (ex: WhatsApp) verificar se tem template
            if campaign.respond_to?(:message_template) && campaign.message_template.present?
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

      # Corrigido: combinando todos os parâmetros em um único hash (3º argumento)
      message = Messages::MessageBuilder.new(
        campaign.sender || campaign.inbox.account.agents.first, # 1º argumento: usuário
        conversation,                                           # 2º argumento: conversa
        {                                                       # 3º argumento: parâmetros
          message_type: :outgoing,
          content: campaign.message_template.content,
          template: campaign.message_template,
          template_params: campaign.message_template.try(:template_params)
        }
      ).perform

      Rails.logger.info "Template enviado para #{contact.phone_number}, mensagem ##{message.id}"
      message
    end

    def send_text_message(contact)
      contact_inbox = find_or_create_contact_inbox(contact)
      return unless contact_inbox

      conversation = find_or_create_conversation(contact_inbox)

      # Corrigido: combinando todos os parâmetros em um único hash (3º argumento)
      message = Messages::MessageBuilder.new(
        campaign.sender || campaign.inbox.account.agents.first, # 1º argumento: usuário
        conversation,                                           # 2º argumento: conversa
        {                                                       # 3º argumento: parâmetros
          message_type: :outgoing,
          content: campaign.message
        }
      ).perform

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
      # Remove caracteres não numéricos do telefone para usar como source_id
      phone_digits = contact.phone_number.gsub(/[^\d]/, '')
      "#{phone_digits}#{rand(1000..9999)}"
    end
  end
end
