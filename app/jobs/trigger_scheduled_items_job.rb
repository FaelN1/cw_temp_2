class TriggerScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Rails.logger.info("Iniciando verificação de campanhas agendadas em #{Time.current}")

    # Buscar todas as campanhas ativas e habilitadas, sem filtro de data
    campaigns = Campaign.where(campaign_status: :active, enabled: true)
                       .includes(:inbox) # Pré-carrega os inboxes para evitar consultas N+1

    Rails.logger.info("Encontradas #{campaigns.size} campanhas agendadas")

    # Processar cada campanha individualmente
    campaigns.find_each do |campaign|
      # Verifica o tipo de inbox sem usar a coluna diretamente
      inbox_type = campaign.inbox.try(:channel).try(:class).try(:name)
      Rails.logger.info("Verificando campanha ##{campaign.id}: inbox_channel_type=#{inbox_type}")

      # Acionar o job de processamento
      Campaigns::TriggerOneoffCampaignJob.perform_later(campaign)
      Rails.logger.info("Agendado processamento para campanha ##{campaign.id}")
    end

    # Job to reopen snoozed conversations
    Conversations::ReopenSnoozedConversationsJob.perform_later

    # Job to reopen snoozed notifications
    Notification::ReopenSnoozedNotificationsJob.perform_later

    # Job to auto-resolve conversations
    Account::ConversationsResolutionSchedulerJob.perform_later

    # Job to sync whatsapp templates
    Channels::Whatsapp::TemplatesSyncSchedulerJob.perform_later

    # Job to clear notifications which are older than 1 month
    Notification::RemoveOldNotificationJob.perform_later
  end
end

TriggerScheduledItemsJob.prepend_mod_with('TriggerScheduledItemsJob')
