class Campaigns::BaseService
  pattr_initialize [:campaign!]

  def perform
    raise NotImplementedError, 'Classes que herdam de BaseService devem implementar o método #perform'
  end

  private

  def audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def mark_campaign_completed
    campaign.completed!
  end

  def mark_campaign_failed
    campaign.failed!
  end

  # Utility method to get contacts from labels
  def contacts_from_labels(labels)
    campaign.account.contacts.tagged_with(labels, any: true)
  end

  # Log helper to standardize logging across campaign services
  def log(message, level = :info)
    message = "[Campaign ##{campaign.id}] #{message}"
    case level
    when :info
      Rails.logger.info(message)
    when :error
      Rails.logger.error(message)
    when :warn
      Rails.logger.warn(message)
    end
  end
end
