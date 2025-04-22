class Api::V1::Accounts::Contacts::LabelsController < Api::V1::Accounts::Contacts::BaseController
  include LabelConcern

  def create
    ActiveRecord::Base.transaction do
      # Remover labels existentes
      @contact.taggings.destroy_all

      # Adicionar novas labels
      permitted_params[:labels].each do |label_name|
        # Encontra ou cria a etiqueta
        label = @contact.account.labels.find_or_create_by!(title: label_name)

        # Associa explicitamente o contato à etiqueta
        @contact.taggings.create!(tag_id: label.id, taggable_type: 'Contact')
      end

      # Log para debug
      Rails.logger.info("Etiquetas aplicadas ao contato ##{@contact.id}: #{permitted_params[:labels].inspect}")
      Rails.logger.info("IDs das etiquetas aplicadas: #{@contact.taggings.includes(:tag).map { |t| t.tag.id }.inspect}")
    end

    render json: { message: 'Labels atribuídas com sucesso', labels: @contact.taggings.includes(:tag).map { |t| t.tag.title } }
  end

  private

  def model
    @model ||= @contact
  end

  def permitted_params
    params.permit(labels: [])
  end
end
