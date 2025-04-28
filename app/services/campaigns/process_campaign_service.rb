class Campaigns::ProcessCampaignService
  pattr_initialize [:campaign!]

  def perform
    return if campaign.completed?

    service_class = find_service_class
    if service_class
      service_class.new(campaign: campaign).perform
    else
      Rails.logger.error "No service found to process campaign #{campaign.id} for inbox type #{campaign.inbox.inbox_type}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "Error processing campaign #{campaign.id}: #{e.message}"
    false
  end

  private

  def find_service_class
    case campaign.inbox.inbox_type
    when 'Sms'
      Sms::OneoffSmsCampaignService
    when 'Twilio SMS'
      Twilio::OneoffSmsCampaignService
    when 'Whatsapp'
      if defined?(Whatsapp::OneoffWhatsappCampaignService)
        Whatsapp::OneoffWhatsappCampaignService
      end
    else
      nil
    end
  end
end
