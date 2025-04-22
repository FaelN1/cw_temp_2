# == Schema Information
#
# Table name: campaigns
#
#  id                                 :bigint           not null, primary key
#  audience                           :jsonb
#  campaign_status                    :integer          default("active"), not null
#  campaign_type                      :integer          default("ongoing"), not null
#  description                        :text
#  enabled                            :boolean          default(TRUE)
#  message                            :text             not null
#  scheduled_at                       :datetime
#  title                              :string           not null
#  trigger_only_during_business_hours :boolean          default(FALSE)
#  trigger_rules                      :jsonb
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  account_id                         :bigint           not null
#  display_id                         :integer          not null
#  inbox_id                           :bigint           not null
#  sender_id                          :integer
#
# Indexes
#
#  index_campaigns_on_account_id       (account_id)
#  index_campaigns_on_campaign_status  (campaign_status)
#  index_campaigns_on_campaign_type    (campaign_type)
#  index_campaigns_on_inbox_id         (inbox_id)
#  index_campaigns_on_scheduled_at     (scheduled_at)
#
class Campaign < ApplicationRecord
  include UrlHelper
  validates :account_id, presence: true
  validates :inbox_id, presence: true
  validates :title, presence: true

  # Alterando a validação para verificar se template_params está presente no hash de params
  # durante a criação/atualização, em vez de verificar a coluna já salva
  validate :message_or_template_params_present
  validate :validate_campaign_inbox
  validate :validate_url
  validate :prevent_completed_campaign_from_update, on: :update
  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true

  enum campaign_type: { ongoing: 0, one_off: 1 }
  # TODO : enabled attribute is unneccessary . lets move that to the campaign status with additional statuses like draft, disabled etc.
  enum campaign_status: { active: 0, completed: 1 }

  has_many :conversations, dependent: :nullify, autosave: true

  before_validation :ensure_correct_campaign_attributes
  after_commit :set_display_id, unless: :display_id?

  def trigger!
    Rails.logger.info("Tentando disparar campanha ##{id}: tipo=#{campaign_type}, status=#{campaign_status}, canal=#{inbox&.channel&.class&.name}")

    # Verificar o tipo de canal ao invés do inbox_type
    channel_type = inbox.channel.class.name

    # Para campanhas WhatsApp, permitir tanto ONGOING quanto ONE_OFF
    if channel_type == 'Channel::Whatsapp'
      Rails.logger.info("Disparando campanha WhatsApp ##{id}")
      Whatsapp::OneoffWhatsappCampaignService.new(campaign: self).perform
      return
    end

    # Para outros tipos, manter a lógica original
    return unless one_off?
    return if completed?

    if channel_type == 'Channel::TwilioSms'
      Rails.logger.info("Disparando campanha Twilio SMS ##{id}")
      Twilio::OneoffSmsCampaignService.new(campaign: self).perform
    elsif channel_type == 'Channel::Sms'
      Rails.logger.info("Disparando campanha SMS ##{id}")
      Sms::OneoffSmsCampaignService.new(campaign: self).perform
    end
  end

  private

  # Corrigimos o método message_or_template_params_present para verificar template_params corretamente
  def message_or_template_params_present
    # Não deve exigir mensagem se template_params estiver presente
    if template_params.blank? || template_params.empty?
      errors.add(:message, :blank) if message.blank?
    end
  end

  def set_display_id
    reload
  end

  def validate_campaign_inbox
    return unless inbox

    # Verificar o tipo de canal ao invés do tipo de inbox
    channel_type = inbox.channel.class.name

    # Usar os nomes das classes de canal ao invés do tipo de inbox
    valid_types = ['Channel::WebWidget', 'Channel::TwilioSms', 'Channel::Sms', 'Channel::Api', 'Channel::Whatsapp']
    unless valid_types.include?(channel_type)
      errors.add :inbox, 'Unsupported Inbox type'
    end
  end

  def valid_campaign_inbox
    return unless inbox_id.present?

    inbox = account.inboxes.find_by(id: inbox_id)
    unless inbox
      errors.add(:inbox, I18n.t('errors.campaign.inbox.not_found'))
      return
    end

    # Modificação aqui para aceitar inboxes API e WhatsApp
    allowed_inbox_types = ['Channel::Api', 'Channel::Whatsapp']
    return if allowed_inbox_types.include?(inbox.channel_type)

    errors.add(:inbox, I18n.t('errors.campaign.inbox.unsupported_inbox_type'))
  end

  # TO-DO we clean up with better validations when campaigns evolve into more inboxes
  def ensure_correct_campaign_attributes
    return if inbox.blank?

    # Verificar o tipo de canal ao invés do tipo de inbox
    channel_type = inbox.channel.class.name

    if ['Channel::TwilioSms', 'Channel::Sms'].include?(channel_type)
      self.campaign_type = 'one_off'
      self.scheduled_at ||= Time.now.utc
    elsif channel_type == 'Channel::Whatsapp' && scheduled_at.present?
      # Se for WhatsApp e tiver data de agendamento, também será one_off
      self.campaign_type = 'one_off'
    else
      self.campaign_type = 'ongoing'
      self.scheduled_at = nil
    end

    Rails.logger.info("Campanha ##{id || 'nova'} configurada: tipo=#{campaign_type}, agendamento=#{scheduled_at}, canal=#{channel_type}")
  end

  def validate_url
    return unless trigger_rules['url']

    use_http_protocol = trigger_rules['url'].starts_with?('http://') || trigger_rules['url'].starts_with?('https://')
    errors.add(:url, 'invalid') if inbox.inbox_type == 'Website' && !use_http_protocol
  end

  def prevent_completed_campaign_from_update
    errors.add :status, 'The campaign is already completed' if !campaign_status_changed? && completed?
  end

  # creating db triggers
  trigger.before(:insert).for_each(:row) do
    "NEW.display_id := nextval('camp_dpid_seq_' || NEW.account_id);"
  end
end
