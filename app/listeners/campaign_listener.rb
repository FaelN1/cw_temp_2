class CampaignListener < BaseListener
  def campaign_triggered(event)
    campaign = extract_campaign(event)
    return if campaign.blank?

    campaign.trigger!
  end

  def campaign_scheduled(event)
    # Este evento é para futuras implementações de agendamento
    # Será acionado quando uma campanha for agendada
  end

  private

  def extract_campaign(event)
    campaign = event.data[:campaign]
    return campaign if campaign.is_a?(Campaign)

    Campaign.find_by(id: campaign[:id])
  end
end
