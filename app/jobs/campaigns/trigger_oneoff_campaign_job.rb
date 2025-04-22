class Campaigns::TriggerOneoffCampaignJob < ApplicationJob
  queue_as :campaigns

  def perform(campaign)
    # Log no início para diagnóstico
    Rails.logger.info("TriggerOneoffCampaignJob iniciado para campanha ##{campaign.id}, status: #{campaign.campaign_status}")

    if campaign.completed?
      Rails.logger.info("Campanha ##{campaign.id} já está concluída, pulando processamento")
      return
    end

    Rails.logger.info("Processando campanha ##{campaign.id} (#{campaign.title})")

    # Obter o tipo de inbox usando o canal associado
    inbox = campaign.inbox
    channel = inbox.channel

    Rails.logger.info("Inbox ##{inbox.id}, Canal: #{channel.class.name}")

    # Usar a informação do canal para determinar o tipo correto
    case channel.class.name
    when 'Channel::TwilioSms'
      Rails.logger.info("Disparando campanha Twilio SMS ##{campaign.id}")
      Twilio::OneoffSmsCampaignService.new(campaign: campaign).perform
    when 'Channel::Sms'
      Rails.logger.info("Disparando campanha SMS ##{campaign.id}")
      Sms::OneoffSmsCampaignService.new(campaign: campaign).perform
    when 'Channel::Whatsapp'
      Rails.logger.info("Disparando campanha WhatsApp ##{campaign.id} (tipo: #{campaign.campaign_type})")
      # WhatsApp pode ser tanto ONGOING quanto ONE_OFF
      Whatsapp::OneoffWhatsappCampaignService.new(campaign: campaign).perform
    when 'Channel::Api'
      Rails.logger.info("Disparando campanha API ##{campaign.id}")
      Whatsapp::OneoffWhatsappCampaignService.new(campaign: campaign).perform
    else
      Rails.logger.warn("Tipo de canal não suportado para campanhas: #{channel.class.name}")
    end

    # Marcar campanha como concluída se for do tipo one_off
    # (Campanha WhatsApp já é marcada como concluída dentro do serviço)
    if campaign.one_off? && channel.class.name != 'Channel::Whatsapp'
      campaign.update(campaign_status: :completed)
      Rails.logger.info("Campanha ##{campaign.id} marcada como concluída")
    end
  rescue StandardError => e
    Rails.logger.error("Erro ao processar campanha ##{campaign.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise # Relançar o erro para que o job possa tentar novamente
  end
end
