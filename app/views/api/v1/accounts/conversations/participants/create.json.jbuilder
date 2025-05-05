json.array! @participants do |participant|
  json.id participant.id
  json.user_id participant.user_id

  if participant.user.present?
    json.user do
      json.id participant.user.id
      json.name participant.user.name
      json.available_name participant.user.available_name
      json.avatar_url participant.user.avatar_url
      json.type 'user'
      json.availability_status participant.user.availability_status
      json.thumbnail participant.user.avatar_url
      # Adicionar informações de role
      if participant.user.current_account_user.present?
        json.role participant.user.current_account_user.role
        json.administrator participant.user.administrator?
      end
    end
  else
    json.user nil
  end
end
