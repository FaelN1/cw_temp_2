json.id resource.id
json.email resource.email
json.name resource.name
json.available_name resource.available_name
json.avatar_url resource.avatar_url
json.type resource.type
json.created_at resource.created_at
json.updated_at resource.updated_at
json.custom_attributes resource.custom_attributes
json.message_signature resource.message_signature
json.display_name resource.display_name
json.confirmed resource.confirmed?

# Incluir informações detalhadas das contas do usuário
json.accounts resource.account_users do |account_user|
  json.id account_user.account_id
  json.role account_user.role
  json.role_name account_user.role # Isto mostrará o nome do enum ao invés do valor numérico
  json.availability account_user.availability
  json.availability_name account_user.availability # Nome do enum de disponibilidade
  json.auto_offline account_user.auto_offline
  json.custom_role_id account_user.custom_role_id
end
