class Api::V1::Accounts::CampaignsController < Api::V1::Accounts::BaseController
  before_action :fetch_campaign, except: [:index, :create]
  before_action :check_authorization

  def index
    @campaigns = Current.account.campaigns
  end

  def show; end

  def create
    # Adicionar logs para debugar
    Campaigns::LoggerService.log_campaign_creation(campaign_params)

    begin
      ActiveRecord::Base.transaction do
        @campaign = Current.account.campaigns.create!(campaign_params)
        @campaign.file.attach(params[:file]) if params[:file].present?
      end
    rescue => e
      Campaigns::LoggerService.log_campaign_error(e)
      render_could_not_create_error(e.message)
    end
  end

  def update
    @campaign.update!(campaign_params)
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  private

  def fetch_campaign
    @campaign ||= Current.account.campaigns.find_by(display_id: params[:id])
  end

  def campaign_params
    # Logando os parâmetros puros para identificar qualquer problema
    Rails.logger.info("Parâmetros brutos recebidos: #{params.inspect}")

    params.permit(
      :title, :description, :message, :sender_id, :inbox_id, :scheduled_at, :campaign_type, :tag_ids, :audience_size, :enabled, :trigger_rules,
      audience: [:id, :type]
    )
  end
end
