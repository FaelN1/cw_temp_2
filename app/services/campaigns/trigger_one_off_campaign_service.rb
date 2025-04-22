class Campaigns::TriggerOneOffCampaignService
  pattr_initialize [:campaign!]

  def perform
    return if campaign.completed?

    # Logs para diagnóstico
    Rails.logger.info("TriggerOneoffCampaignJob iniciado para campanha ##{campaign.id}, status: #{campaign.status}")
    Rails.logger.info("Processando campanha ##{campaign.id} (#{campaign.title})")

    # Log detalhado sobre a audiência
    Rails.logger.info("Tipo de dados da audiência: #{campaign.audience.class.name}, Conteúdo: #{campaign.audience.inspect}")

    if campaign.audience.present?
      # Se tem etiquetas na audiência, processa
      if campaign.audience.any? { |a| a['type'] == 'Label' }
        # Log sobre as etiquetas
        label_ids = campaign.audience.select { |a| a['type'] == 'Label' }.map { |a| a['id'] }
        Rails.logger.info("Filtrando contatos por etiquetas: #{label_ids.join(', ')}")

        # Buscar etiquetas para log
        labels = Label.where(id: label_ids)
        Rails.logger.info("Etiquetas encontradas: #{labels.pluck(:title).join(', ')}")
        Rails.logger.info("Labels encontradas (detalhado): #{labels.as_json}")
      end
    end

    # Usar o novo serviço de busca de contatos
    contacts = Campaigns::ContactFinderService.new(campaign: campaign).perform

    if contacts.present?
      # Contagem e detalhes para log
      Rails.logger.info("Audiência filtrada final TriggerOneOffCampaignService: #{contacts.size} contatos")
      Rails.logger.info("Detalhes dos contatos encontrados: #{contacts.as_json(only: [:id, :name, :email, :phone_number])}")

      # Processar canal específico
      process_campaign(contacts)
    else
      # Nenhum contato encontrado
      Rails.logger.info("Audiência filtrada final TriggerOneOffCampaignService: 0 contatos")
      Rails.logger.info("Campanha #{campaign.inbox.channel_type} ##{campaign.id}: Processando 0 contatos")
      Rails.logger.info("Campanha #{campaign.inbox.channel_type} ##{campaign.id} concluída: enviados=0, falhas=0")

      # Marcar como completa mesmo sem contatos
      campaign.update!(status: :completed)
    end
  end

  private

  def process_campaign(contacts)
    channel_type = campaign.inbox.channel_type
    Rails.logger.info("Inbox ##{campaign.inbox_id}, Canal: #{channel_type}")
    Rails.logger.info("Disparando campanha #{channel_type} ##{campaign.id}")

    Rails.logger.info("Iniciando serviço de campanha #{channel_type} para ##{campaign.id}")
    campaign_instance = campaign_service(channel_type).new(campaign: campaign)

    # Processamento dos contatos
    Rails.logger.info("Campanha #{channel_type} ##{campaign.id}: Processando #{contacts.size} contatos")
    sent_count = 0
    failed_count = 0

    contacts.each do |contact|
      begin
        campaign_instance.process_campaign_for_contact(contact)
        sent_count += 1
      rescue StandardError => e
        failed_count += 1
        Rails.logger.error("Erro ao processar contato #{contact.id} para campanha #{campaign.id}: #{e.message}")
      end
    end

    Rails.logger.info("Campanha #{channel_type} ##{campaign.id} concluída: enviados=#{sent_count}, falhas=#{failed_count}")

    # Marcar como completa
    campaign.update!(status: :completed)
  end

  def campaign_service(channel_type)
    case channel_type
    when 'Channel::Api'
      Campaigns::ApiService
    when 'Channel::Email'
      Campaigns::EmailService
    when 'Channel::Sms'
      Campaigns::SmsService
    when 'Channel::Whatsapp'
      Campaigns::WhatsappService
    when 'Channel::Facebook', 'Channel::TwitterProfile', 'Channel::Telegram', 'Channel::Line', 'Channel::Twilio'
      Campaigns::ConversationService
    end
  end
end
