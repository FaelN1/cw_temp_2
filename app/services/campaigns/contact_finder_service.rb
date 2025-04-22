class Campaigns::ContactFinderService
  pattr_initialize [:campaign!]

  def perform
    audience_label_ids = campaign.audience.select { |a| a['type'] == 'Label' }.map { |a| a['id'] }
    return [] if audience_label_ids.blank?

    # Log para debug
    Rails.logger.info("ContactFinderService: Buscando contatos para campanha ##{campaign.id}")
    Rails.logger.info("ContactFinderService: IDs de etiquetas: #{audience_label_ids.inspect}")

    account_id = campaign.account_id
    # Buscar contatos por etiqueta usando o modelo ContactsLabelsRelation
    contacts = find_contacts_with_labels(account_id, audience_label_ids)

    Rails.logger.info("ContactFinderService: Encontrados #{contacts.count} contatos com as etiquetas selecionadas")

    contacts.uniq
  end

  private

  def find_contacts_with_labels(account_id, label_ids)
    # Buscar diretamente na tabela de relacionamento entre contatos e etiquetas
    # Usando SQL para encontrar exatamente os contatos que têm as etiquetas especificadas
    contacts = Contact.where(account_id: account_id)
                      .joins("INNER JOIN taggings ON taggings.taggable_id = contacts.id")
                      .joins("INNER JOIN tags ON tags.id = taggings.tag_id")
                      .where("taggings.taggable_type = 'Contact'")
                      .where("tags.id IN (?)", label_ids)
                      .distinct

    # Log detalhado para diagnóstico
    Rails.logger.info("ContactFinderService: Consulta SQL: #{contacts.to_sql}")
    Rails.logger.info("ContactFinderService: IDs de contatos encontrados: #{contacts.pluck(:id).inspect}")

    contacts
  end
end
