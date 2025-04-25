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
          # Usar um método de permissão específico para 'create' que permite audience/template_params como string
          raw_params = permitted_params_for_create
          attachment = raw_params[:attachment] # Guardar o anexo

          # Preparar atributos para Campaign.new, excluindo o anexo por enquanto
          campaign_attributes = raw_params.except(:attachment)

          # Processar audience: parse se for string JSON
          if campaign_attributes[:audience].is_a?(String)
            begin
              parsed_audience = JSON.parse(campaign_attributes[:audience])
              # Garantir que seja um array após o parse
              campaign_attributes[:audience] = parsed_audience.is_a?(Array) ? parsed_audience : nil
            rescue JSON::ParserError
              # Lidar com JSON inválido (ex: definir como nil ou adicionar erro)
              @campaign = Campaign.new # Criar um objeto para adicionar erros
              @campaign.errors.add(:audience, :invalid_json)
              render json: { error: @campaign.errors.full_messages.to_sentence }, status: :unprocessable_entity and return
            end
          end

          # Processar template_params: parse se for string JSON
          if campaign_attributes[:template_params].is_a?(String)
            begin
              parsed_template_params = JSON.parse(campaign_attributes[:template_params])
              campaign_attributes[:template_params] = parsed_template_params.is_a?(Hash) ? parsed_template_params : nil
            rescue JSON::ParserError
              @campaign = Campaign.new
              @campaign.errors.add(:template_params, :invalid_json)
              render json: { error: @campaign.errors.full_messages.to_sentence }, status: :unprocessable_entity and return
            end
          end

          # Inicializar a campanha com os atributos processados
          @campaign = Current.account.campaigns.new(campaign_attributes)

          # Lógica para salvar com ou sem anexo
          if attachment.present?
            # Flag para usar o texto como caption do anexo
            @campaign.additional_attributes ||= {}
            @campaign.additional_attributes['use_message_as_attachment_caption'] = true

            if @campaign.save
              # Criar o anexo após salvar a campanha
              @campaign.attachments.create!(
                account_id: Current.account.id,
                file_type: detect_file_type(attachment),
                file: attachment
              )
              render json: @campaign
            else
              # Usar full_messages para erros mais claros
              render json: { error: @campaign.errors.full_messages.to_sentence }, status: :unprocessable_entity
            end
          else
            # Sem anexo, apenas salvar a campanha normalmente
            if @campaign.save
              render json: @campaign
            else
              render json: { error: @campaign.errors.full_messages.to_sentence }, status: :unprocessable_entity
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

        # Método de permissão original (pode ser usado para update ou refatorado)
        def permitted_params
          params.permit(
            :title, :description, :sender_id, :message, :enabled, :inbox_id,
            :scheduled_at, :campaign_type, :campaign_status,
            :trigger_only_during_business_hours,
            :attachment,
            audience: [:id, :type], # Permite array de hashes (JSON normal)
            trigger_rules: {},
            template_params: {} # Permite hash (JSON normal)
          )
        end

        # Novo método de permissão específico para 'create' com FormData
        def permitted_params_for_create
          params.permit(
            :title, :description, :sender_id, :message, :enabled, :inbox_id,
            :scheduled_at, :campaign_type, :campaign_status,
            :trigger_only_during_business_hours,
            :attachment,
            :audience, # Permite audience como escalar (string)
            :template_params # Permite template_params como escalar (string)
            # trigger_rules ainda precisa ser hash, se aplicável
            # trigger_rules: {}
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
