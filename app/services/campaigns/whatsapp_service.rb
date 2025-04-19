class Campaigns::WhatsappService < Campaigns::BaseService
  private

  def campaign_valid?
    campaign.valid?
  end

  def valid_inbox_type?
    return true if ['Channel::Api', 'Channel::Whatsapp'].include?(inbox.channel_type)

    false
  end

  def process_campaign_service
    return unless valid_inbox_type?

    # Código existente
    process_audience
  end

  def send_message(contact)
    case inbox.channel_type
    when 'Channel::Whatsapp'
      # Envio específico para WhatsApp
      send_whatsapp_message(contact)
    when 'Channel::Api'
      # Envio específico para API
      send_api_message(contact)
    end
  end

  def send_whatsapp_message(contact)
    # Implementação existente para WhatsApp...
  end

  def send_api_message(contact)
    contact_inbox = contact.contact_inboxes.find_by(inbox: inbox)

    # Cria um contact_inbox se não existir
    if contact_inbox.blank?
      source_id = SecureRandom.uuid
      contact_inbox = ContactInbox.create!(
        contact: contact,
        inbox: inbox,
        source_id: source_id
      )
    end

    conversation = Conversation.where(
      contact_inbox_id: contact_inbox.id,
      inbox_id: inbox.id,
      status: :open
    ).first

    # Cria uma nova conversa se não existir uma aberta
    if conversation.blank?
      conversation = Conversation.create!(
        account_id: campaign.account_id,
        inbox_id: inbox.id,
        contact_id: contact.id,
        contact_inbox_id: contact_inbox.id,
        campaign_id: campaign.id
      )
    end

    # Criar a mensagem
    Messages::OutgoingMessageService.new(
      message: {
        content: campaign_message,
        message_type: :outgoing,
        content_type: 'text',
        conversation_id: conversation.id,
        inbox_id: inbox.id
      },
      campaign: campaign
    ).perform
  end
end
