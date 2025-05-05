json.additional_attributes contact.additional_attributes
json.availability_status contact.availability_status
json.email contact.email
json.id contact.id
json.name contact.name
json.phone_number contact.phone_number
json.identifier contact.identifier
json.thumbnail contact.avatar_url
json.custom_attributes contact.custom_attributes
json.last_activity_at contact.last_activity_at.to_i if contact[:last_activity_at].present?
json.created_at contact.created_at.to_i if contact[:created_at].present?
# we only want to output contact inbox when its /contacts endpoints
if defined?(with_contact_inboxes) && with_contact_inboxes.present?
  json.contact_inboxes do
    json.array! contact.contact_inboxes do |contact_inbox|
      json.partial! 'api/v1/models/contact_inbox', formats: [:json], resource: contact_inbox
    end
  end
end
