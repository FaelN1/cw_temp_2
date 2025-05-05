json.payload do
  json.array! @contacts do |contact|
    json.partial! 'api/v1/models/contact', formats: [:json], resource: contact
  end
end

json.meta do
  json.count @contacts_count
  json.current_page @current_page
end
