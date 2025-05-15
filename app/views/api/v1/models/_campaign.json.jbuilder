json.id resource.display_id
json.title resource.title
json.description resource.description
json.account_id resource.account_id
json.inbox do
  json.partial! 'api/v1/models/inbox', formats: [:json], resource: resource.inbox
end
json.message resource.message
json.campaign_status resource.campaign_status
json.enabled resource.enabled
json.campaign_type resource.campaign_type
json.trigger_rules resource.trigger_rules
json.trigger_only_during_business_hours resource.trigger_only_during_business_hours
# Adicionando o campo scheduled_at à resposta JSON
json.scheduled_at resource.scheduled_at
json.audience resource.audience
json.created_at resource.created_at
json.updated_at resource.updated_at

# Adicionar informações do anexo
if resource.attachments.present?
  json.attachment do
    attachment = resource.attachments.first
    json.id attachment.id
    json.file_type attachment.file_type
    json.data_url attachment.file_url
    json.thumb_url attachment.thumb_url if attachment.file_type == 'image'
  end
end
