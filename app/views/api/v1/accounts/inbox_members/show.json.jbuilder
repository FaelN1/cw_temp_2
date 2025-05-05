json.agents @agents do |agent|
  json.id agent.id
  json.email agent.email
  json.name agent.name
  json.available_name agent.available_name
  json.avatar_url agent.avatar_url
  json.availability_status agent.availability_status
  # Adicionar informações específicas de account_user
  if agent.current_account_user.present?
    json.role agent.current_account_user.role
    json.role_value agent.current_account_user.role_before_type_cast # Valor numérico
    json.administrator agent.administrator?
    json.agent agent.agent?
  end
end
