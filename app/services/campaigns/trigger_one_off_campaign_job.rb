class Campaigns::TriggerOneOffCampaignJob < ApplicationJob
  queue_as :campaigns

  def perform(campaign)
    return unless campaign.active?

    Rails.logger.info "TriggerOneoffCampaignJob iniciado para campanha ##{campaign.id}, status: #{campaign.status}"
    Rails.logger.info "Processando campanha ##{campaign.id} (#{campaign.title})"
    Rails.logger.info "Inbox ##{campaign.inbox.id}, Canal: #{campaign.inbox.channel_type}"

    case campaign.inbox.channel_type
    when 'Channel::Whatsapp', 'Channel::Api'
      Rails.logger.info "Disparando campanha WhatsApp/API ##{campaign.id}"
      Rails.logger.info "Iniciando serviço de campanha WhatsApp para ##{campaign.id}"
      ::Whatsapp::OneoffWhatsappCampaignService.new(campaign: campaign).perform
    when 'Channel::Sms', 'Channel::Twilio'
      Rails.logger.info "Disparando campanha SMS ##{campaign.id}"
      Rails.logger.info "Iniciando serviço de campanha SMS para ##{campaign.id}"
      ::Sms::OneoffSmsCampaignService.new(campaign: campaign).perform
    else
      Rails.logger.info "Disparando campanha API ##{campaign.id}"
      Rails.logger.info "Iniciando serviço de campanha API para ##{campaign.id}"
      process_api_campaign(campaign)
    end
  end

  private

  def process_api_campaign(campaign)
    Rails.logger.info "Tipo de dados da audiência: #{campaign.audience.class}, Conteúdo: #{campaign.audience.inspect}"
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    Rails.logger.info "Filtrando contatos por etiquetas: #{audience_label_ids.join(', ')}"

    audience_labels = campaign.account.labels.where(id: audience_label_ids)
    Rails.logger.info "Etiquetas encontradas: #{audience_labels.pluck(:title).join(', ')}"
    Rails.logger.info "Labels encontradas (detalhado): #{audience_labels.to_json}"

    label_titles = audience_labels.pluck(:title)
    Rails.logger.info "Buscando contatos com labels: #{label_titles}"

    contacts = campaign.account.contacts.tagged_with(label_titles, any: true)
    Rails.logger.info "IDs de contatos com estas etiquetas: #{contacts.pluck(:id)}"
    Rails.logger.info "Detalhes dos contatos encontrados: #{contacts.to_json}"
    Rails.logger.info "Audiência filtrada final TriggerOneoffCampaignJob: #{contacts.count} contatos"

    sent_count = 0
    failed_count = 0

    Rails.logger.info "Campanha API ##{campaign.id}: Processando #{contacts.count} contatos"

    # Lógica existente para processar cada contato...

    Rails.logger.info "Campanha API ##{campaign.id} concluída: enviados=#{sent_count}, falhas=#{failed_count}"
  end
end
