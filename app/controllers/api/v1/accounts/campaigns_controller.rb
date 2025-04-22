module Api
  module V1
    module Accounts
      class CampaignsController < Api::V1::Accounts::BaseController
        before_action :fetch_campaign, except: [:index, :create]
        before_action :check_authorization

        def index
          @campaigns = Current.account.campaigns
          @campaigns = @campaigns.where(campaign_type: params[:campaign_type]) if params[:campaign_type].present?
          @campaigns = @campaigns.order(created_at: :desc)
        end

        def create
          # Processar template_params diretamente se estiver presente
          if permitted_params[:template_params].present?
            @campaign = Current.account.campaigns.new(permitted_params.except(:template_params))
            @campaign.template_params = permitted_params[:template_params]
          else
            @campaign = Current.account.campaigns.new(permitted_params)
          end

          if @campaign.save
            render json: @campaign
          else
            render json: { error: @campaign.errors.messages }.to_json, status: :unprocessable_entity
          end
        end

        def show
          render json: @campaign
        end

        def update
          # Processar template_params diretamente se estiver presente
          if permitted_params[:template_params].present?
            if @campaign.update(permitted_params.except(:template_params))
              @campaign.update_column(:template_params, permitted_params[:template_params])
              render json: @campaign
            else
              render json: { error: @campaign.errors.messages }.to_json, status: :unprocessable_entity
            end
          else
            if @campaign.update(permitted_params)
              render json: @campaign
            else
              render json: { error: @campaign.errors.messages }.to_json, status: :unprocessable_entity
            end
          end
        end

        def destroy
          @campaign.destroy!
          head :ok
        end

        private

        def fetch_campaign
          @campaign = Current.account.campaigns.find(params[:id])
        end

        def check_authorization
          authorize(Campaign)
        end

        def permitted_params
          # Adicione template_params à lista de parâmetros permitidos
          params.permit(
            :title,
            :description,
            :sender_id,
            :message,
            :enabled,
            :inbox_id,
            :scheduled_at,
            :campaign_type,
            :campaign_status,
            :trigger_only_during_business_hours,
            audience: [:id, :type],
            trigger_rules: {},
            template_params: {}
          )
        end
      end
    end
  end
end
