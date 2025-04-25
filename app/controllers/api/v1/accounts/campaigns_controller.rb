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
          # Remover attachment dos parâmetros permitidos
          campaign_params = permitted_params.except(:attachment)

          # Processar audience como JSON se vier como string
          if campaign_params[:audience].is_a?(String)
            campaign_params[:audience] = JSON.parse(campaign_params[:audience])
          end

          # Processar template_params se presente
          if campaign_params[:template_params].present?
            if campaign_params[:template_params].is_a?(String)
              campaign_params[:template_params] = JSON.parse(campaign_params[:template_params])
            end
            template_params = campaign_params.delete(:template_params)
          end

          # Criar campanha sem o anexo
          @campaign = Current.account.campaigns.new(campaign_params)

          # Adicionar template_params se presentes
          if template_params.present?
            @campaign.template_params = template_params
          end

          # Processar o anexo, se presente
          if params[:attachment].present?
            # Flag para usar o texto como caption do anexo
            @campaign.additional_attributes ||= {}
            @campaign.additional_attributes['use_message_as_attachment_caption'] = true

            if @campaign.save
              # Criar o anexo após salvar a campanha
              @attachment = @campaign.attachments.create!(
                account_id: Current.account.id,
                file_type: detect_file_type(params[:attachment]),
                file: params[:attachment]
              )
              render json: @campaign
            else
              render json: { error: @campaign.errors.messages }.to_json, status: :unprocessable_entity
            end
          else
            # Sem anexo, apenas salvar a campanha normalmente
            if @campaign.save
              render json: @campaign
            else
              render json: { error: @campaign.errors.messages }.to_json, status: :unprocessable_entity
            end
          end
        end

        def show
          render json: @campaign
        end

        def update
          # Processar template_params diretamente se estiver presente
          campaign_params = permitted_params
          attachment = params[:attachment]

          # Atualizar o anexo se presente
          if attachment.present?
            @campaign.attachment&.destroy if @campaign.attachment.present?
            @campaign.build_attachment(
              account_id: Current.account.id,
              file: attachment
            )

            # Marcar a campanha para utilizar o texto como legenda do anexo
            @campaign.additional_attributes ||= {}
            @campaign.additional_attributes['use_message_as_attachment_caption'] = true
          end

          # Atualizar outros campos da campanha
          if campaign_params[:template_params].present?
            if @campaign.update(campaign_params.except(:template_params))
              @campaign.template_params = campaign_params[:template_params]
              @campaign.save
              render json: @campaign
            else
              render json: { error: @campaign.errors.messages }.to_json, status: :unprocessable_entity
            end
          else
            if @campaign.update(campaign_params)
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
          # Adicione attachment à lista de parâmetros permitidos
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
            :attachment,
            audience: [:id, :type],
            trigger_rules: {},
            template_params: {}
          )
        end

        def detect_file_type(attachment)
          content_type = attachment.content_type

          if content_type.start_with?('image/')
            :image
          elsif content_type.start_with?('audio/')
            :audio
          elsif content_type.start_with?('video/')
            :video
          else
            :file
          end
        end
      end
    end
  end
end
