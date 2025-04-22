module Api
  class OneoffCampaignService
    pattr_initialize [:campaign!]

    def perform
      return if campaign.completed?

      Rails.logger.info("Iniciando serviço de campanha API para ##{campaign.id}")

      # Marca campanha como concluída para que outros jobs não a processem
      campaign.completed!

      audience_contacts = audience
      Rails.logger.info("Campanha API ##{campaign.id}: Processando #{audience_contacts.size} contatos")

      sent_count = 0
      failed_count = 0

      audience_contacts.each do |contact|
        if send_message_to_contact(contact)
          sent_count += 1
        else
          failed_count += 1
        end
      end

      Rails.logger.info("Campanha API ##{campaign.id} concluída: enviados=#{sent_count}, falhas=#{failed_count}")
    end

    private

    delegate :inbox, to: :campaign
    delegate :channel, to: :inbox

    def audience
      if campaign.audience.present?
        audience_data = campaign.audience
        Rails.logger.info("Tipo de dados da audiência: #{audience_data.class.name}, Conteúdo: #{audience_data.inspect}")

        # Nova lógica para lidar com o formato de array de etiquetas
        if audience_data.is_a?(Array) && audience_data.all? { |item| item["type"] == "Label" }
          label_ids = audience_data.map { |item| item["id"] }
          Rails.logger.info("Filtrando contatos por etiquetas: #{label_ids.join(', ')}")

          label_records = campaign.account.labels.where(id: label_ids)
          label_names = label_records.pluck(:title)

          Rails.logger.info("Etiquetas encontradas: #{label_names.join(', ')}")

          begin
            Rails.logger.info("Buscando contatos com labels: #{label_names.inspect}")
            contacts = campaign.account.contacts.tagged_with(label_names, any: true)

            contact_ids = contacts.pluck(:id)
            Rails.logger.info("IDs de contatos com estas etiquetas: #{contact_ids}")

            if contact_ids.present?
              # Log detalhado dos contatos encontrados
              contacts_info = contacts.select(:id, :name, :email, :phone_number).map do |contact|
                {
                  id: contact.id,
                  name: contact.name,
                  email: contact.email,
                  phone: contact.phone_number,
                  labels: contact.tag_list
                }
              end
              Rails.logger.info("Detalhes dos contatos encontrados: #{contacts_info.to_json}")
            else
              Rails.logger.warn("Nenhum contato encontrado com as etiquetas: #{label_names.join(', ')}")
            end

            return contacts
          rescue => e
            Rails.logger.error("Erro na busca de contatos com etiquetas: #{e.message}")
            Rails.logger.error(e.backtrace.join("\n"))
            return Contact.none
          end
        end

        # Código existente para outros formatos de audiência
        if audience_data.is_a?(String)
          begin
            audience_data = JSON.parse(audience_data)
          rescue JSON::ParserError => e
            Rails.logger.error("Erro ao parsear audiência como JSON: #{e.message}")
            return campaign.inbox.contacts
          end
        end

        audience_type = audience_data.is_a?(Hash) ? audience_data["type"] : nil

        if audience_type == "all"
          contacts = campaign.inbox.contacts
        elsif audience_type == "label" && audience_data["labels"].present?
          labels = audience_data["labels"]
          contacts = campaign.inbox.contacts.tagged_with(labels, any: true)
        else
          Rails.logger.warn("Tipo de audiência desconhecido ou mal formatado: #{audience_type.inspect}")
          contacts = campaign.inbox.contacts
        end

        Rails.logger.info("Audiência filtrada: #{contacts.count} contatos")
        contacts
      else
        campaign.inbox.contacts
      end
    end

    def contact_has_conversation_already?(contact)
      campaign.conversations.where(contact_id: contact.id).exists?
    end

    def send_message_to_contact(contact)
      # Verifica se o contato já tem uma contact_inbox para a inbox atual
      contact_inbox = contact.contact_inboxes.find_by(inbox_id: campaign.inbox.id)

      # Se não tiver, cria uma
      unless contact_inbox
        Rails.logger.info("Criando contact_inbox para contato #{contact.id} (#{contact.name}) no inbox #{campaign.inbox.id}")
        source_id = "api_#{contact.id}_#{Time.now.to_i}"
        contact_inbox = ContactInbox.create!(
          contact: contact,
          inbox: campaign.inbox,
          source_id: source_id
        )
      end

      begin
        Rails.logger.info("Enviando mensagem para contato ##{contact.id}")

        conversation = ::Conversation.create!(
          account_id: campaign.account_id,
          inbox_id: campaign.inbox_id,
          contact_id: contact.id,
          contact_inbox_id: contact_inbox.id,
          campaign_id: campaign.id
        )

        message = Messages::MessageBuilder.new(
          account: campaign.account,
          user: campaign.sender || campaign.inbox.account.agents.first,
          conversation: conversation,
          message_type: :outgoing,
          content: campaign.message
        ).perform

        Rails.logger.info("Mensagem ##{message.id} enviada para contato ##{contact.id}")
        true
      rescue StandardError => e
        Rails.logger.error("Erro ao enviar mensagem para contato ##{contact.id}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        false
      end
    end
  end
end
