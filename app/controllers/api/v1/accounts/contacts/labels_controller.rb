class Api::V1::Accounts::Contacts::LabelsController < Api::V1::Accounts::Contacts::BaseController
  include LabelConcern

  def create
    # Garante que todos os Labels (seu modelo personalizado) existam na conta.
    # Normaliza para minúsculas, conforme definido no seu modelo Label.
    normalized_label_titles = permitted_params[:labels].map { |name| name.strip.downcase }.reject(&:blank?)

    ActiveRecord::Base.transaction do
      # Primeiro, garante que todos os modelos Label personalizados existam ou sejam criados.
      # Isso é importante se você tem validações ou callbacks no seu modelo Label.
      normalized_label_titles.each do |label_title|
        @contact.account.labels.find_or_create_by!(title: label_title)
      end

      # Agora, usa o método correto fornecido por acts-as-taggable-on com o contexto :labels
      @contact.label_list = normalized_label_titles
      @contact.save!
    end

    # Log para debug
    Rails.logger.info("Etiquetas aplicadas ao contato ##{@contact.id}: #{@contact.label_list.inspect}")

    render json: { message: 'Labels atribuídas com sucesso', labels: @contact.label_list }
  rescue ActiveRecord::RecordInvalid => e
    # Se find_or_create_by! falhar no seu modelo Label (ex: validação do Label),
    # ou se @contact.save! falhar (o que pode acontecer se houver problemas com as tags).
    Rails.logger.error("Erro ao atribuir labels: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def model
    @model ||= @contact
  end

  def permitted_params
    params.permit(labels: [])
  end
end
