class Campaigns::TriggerOneoffCampaignJob < ApplicationJob
  queue_as :campaigns

  def perform(campaign)
    return unless campaign.active?

    Rails.logger.info "TriggerOneoffCampaignJob iniciado para campanha ##{campaign.id}, status: #{campaign.status}"
    Rails.logger.info "Processando campanha ##{campaign.id} (#{campaign.title})"
    Rails.logger.info "Inbox ##{campaign.inbox.id}, Canal: #{campaign.inbox.channel_type}"

    case campaign.inbox.channel_type
    when 'Channel::Whatsapp', 'Channel::Api'
      Rails.logger.info "Disparando campanha #{campaign.inbox.channel_type} ##{campaign.id}"
      Rails.logger.info "Iniciando serviço de campanha WhatsApp para ##{campaign.id}"
      ::Whatsapp::OneoffWhatsappCampaignService.new(campaign: campaign).perform
    when 'Channel::Sms', 'Channel::Twilio'
      Rails.logger.info "Disparando campanha SMS ##{campaign.id}"
      Rails.logger.info "Iniciando serviço de campanha SMS para ##{campaign.id}"
      ::Sms::OneoffSmsCampaignService.new(campaign: campaign).perform
    else
      Rails.logger.info "Disparando campanha genérica ##{campaign.id}"
      process_api_campaign(campaign)
    end
  end

  private

  def process_api_campaign(campaign)
    Rails.logger.info "Iniciando serviço de campanha API para ##{campaign.id}"
    ::Api::OneoffCampaignService.new(campaign: campaign).perform
  end
end
