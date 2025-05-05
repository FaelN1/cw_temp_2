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
#  failed                             :integer          default(0), not null
#  it_sent                            :integer          default(0), not null
#  message                            :text             not null
#  scheduled_at                       :datetime
#  status_send                        :integer          default(0), not null
#  template_params                    :jsonb            not null
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

  # Adicionar additional_attributes como atributo serializável
  store :additional_attributes, accessor: [:template_params], coder: JSON

  # Adicionar associação com anexos
  has_many :attachments, as: :attachable, dependent: :destroy

  # Adicionar atributo virtual para o anexo
  attr_accessor :attachment_file

  # Adicionar atributo virtual para o template_params enviado diretamente na API
  attr_accessor :direct_template_params

  before_validation :ensure_correct_campaign_attributes
  before_validation :move_direct_template_params_to_additional_attributes
  before_validation :check_template_params
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

  # Verificar se há anexo e configurar a flag de caption
  def has_attachment?
    attachments.exists?
  end

  # Verificar se o anexo deve usar o texto como caption
  def use_message_as_attachment_caption?
    additional_attributes&.dig('use_message_as_attachment_caption') || has_attachment?
  end

  private

  # Callback para mover template_params direto da API para o additional_attributes
  def move_direct_template_params_to_additional_attributes
    Rails.logger.info "==== Processando template_params direto ===="
    Rails.logger.info "template_params attribute direto: #{direct_template_params.inspect}"
    Rails.logger.info "Template params da tabela: #{attributes['template_params'].inspect}"

    # Verificar se temos dados de template_params enviados diretamente
    if direct_template_params.present?
      Rails.logger.info "Movendo template_params direto para additional_attributes"
      self.additional_attributes ||= {}
      self.additional_attributes['template_params'] = direct_template_params
    elsif attributes['template_params'].present? && attributes['template_params'].is_a?(Hash) && attributes['template_params'] != {}
      # Se o template_params estiver na tabela (como coluna separada), mover para additional_attributes
      Rails.logger.info "Movendo template_params da tabela para additional_attributes"
      self.additional_attributes ||= {}
      self.additional_attributes['template_params'] = attributes['template_params']
    end

    Rails.logger.info "Additional attributes após processamento: #{additional_attributes.inspect}"
  end

  # Log adicional para ver estado atual dos template_params
  def check_template_params
    Rails.logger.info "Check de template_params antes de salvar:"
    Rails.logger.info "additional_attributes: #{additional_attributes.inspect}"
    if additional_attributes.present?
      Rails.logger.info "template_params em additional_attributes: #{additional_attributes['template_params'].inspect}"
    end
  end

  # Corrigido o método message_or_template_params_present para verificar template_params corretamente
  def message_or_template_params_present
    Rails.logger.info "Validando campanha #{id}: message=#{message.inspect}"
    Rails.logger.info "Validando campanha #{id}: additional_attributes=#{additional_attributes.inspect}"
    Rails.logger.info "Validando campanha #{id}: direct_template_params=#{direct_template_params.inspect}"
    Rails.logger.info "Validando campanha #{id}: atributo template_params=#{attributes['template_params'].inspect}"

    has_template = false
    if additional_attributes.present?
      template_params_str = additional_attributes['template_params']
      template_params_sym = additional_attributes[:template_params]

      Rails.logger.info "template_params como string: #{template_params_str.inspect}"
      Rails.logger.info "template_params como símbolo: #{template_params_sym.inspect}"

      has_template = template_params_str.present? || template_params_sym.present?
    end

    # Verificar também se temos direct_template_params
    has_template ||= direct_template_params.present?
    # Verificar se temos na coluna da tabela
    has_template ||= (attributes['template_params'].present? && attributes['template_params'].is_a?(Hash) && attributes['template_params'] != {})

    has_message = message.present?

    Rails.logger.info "Resultado validação: has_message=#{has_message}, has_template=#{has_template}"

    # Se alguma das condições for verdadeira, a validação passa
    return true if has_template || has_message

    # Se chegou aqui, não tem nem mensagem nem template
    errors.add(:message, :blank)
    false
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
