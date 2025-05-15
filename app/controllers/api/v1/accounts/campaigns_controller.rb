module Api
  module V1
    module Accounts
      class CampaignsController < Api::V1::Accounts::BaseController
        before_action :check_authorization
        before_action :fetch_campaign, only: [:show, :update, :destroy]

        def index
          @campaigns = Current.account.campaigns
          @campaigns = @campaigns.where(campaign_type: params[:campaign_type]) if params[:campaign_type].present?
          @campaigns = @campaigns.order(created_at: :desc)
        end

        def create
          # Usar um método de permissão específico para 'create' que permite audience/template_params como string ou array/hash
          raw_params = permitted_params_for_create
          attachment = raw_params[:attachment] # Guardar o anexo

          Rails.logger.info("Raw params: #{raw_params.inspect}")
          Rails.logger.info("Audience params: #{params[:audience].inspect}") if params[:audience].present?
          Rails.logger.info("Attachment: #{attachment.inspect}")

          # Preparar atributos para Campaign.new, excluindo o anexo por enquanto
          campaign_attributes = raw_params.except(:attachment)

          # Verificar se audience está dentro de campaign ou diretamente nos parâmetros
          if params[:campaign].present? && params[:campaign][:audience].present? && campaign_attributes[:audience].nil?
            campaign_attributes[:audience] = params[:campaign][:audience]
          end

          # Processar audience: parse se for string JSON ou usar diretamente se já for array
          if campaign_attributes[:audience].is_a?(String)
            begin
              parsed_audience = JSON.parse(campaign_attributes[:audience])
              # Garantir que seja um array após o parse
              campaign_attributes[:audience] = parsed_audience.is_a?(Array) ? parsed_audience : nil
            rescue JSON::ParserError
              # Lidar com JSON inválido
              @campaign = Campaign.new
              @campaign.errors.add(:audience, :invalid_json)
              render json: { error: @campaign.errors.full_messages.to_sentence }, status: :unprocessable_entity and return
            end
          end

          # Normalizar audience se for um array de ActionController::Parameters
          if campaign_attributes[:audience].is_a?(Array) && campaign_attributes[:audience].any? { |item| item.is_a?(ActionController::Parameters) }
            campaign_attributes[:audience] = campaign_attributes[:audience].map(&:to_h)
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

          # Garantir que scheduled_at seja processado corretamente se estiver presente
          if campaign_attributes[:scheduled_at].present?
            begin
              # Converter para DateTime para garantir formato correto
              campaign_attributes[:scheduled_at] = DateTime.parse(campaign_attributes[:scheduled_at])
            rescue ArgumentError
              @campaign = Campaign.new
              @campaign.errors.add(:scheduled_at, :invalid_datetime)
              render json: { error: @campaign.errors.full_messages.to_sentence }, status: :unprocessable_entity and return
            end
          end

          # Verificar scheduled_at aninhado em campaign
          if params[:campaign].present? && params[:campaign][:scheduled_at].present? && campaign_attributes[:scheduled_at].nil?
            begin
              campaign_attributes[:scheduled_at] = DateTime.parse(params[:campaign][:scheduled_at])
            rescue ArgumentError
              # Ignorar erro de parse aqui, já que é uma tentativa adicional
            end
          end

          Rails.logger.info("Atributos finais para campanha: #{campaign_attributes.inspect}")

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
          @campaign = Current.account.campaigns.find_by(id: params[:id]) ||
                      Current.account.campaigns.find_by!(display_id: params[:id])
        rescue ActiveRecord::RecordNotFound => e
          raise e
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

        # Método de permissão específico para 'create' atualizado
        def permitted_params_for_create
          params.permit(
            :title, :description, :sender_id, :message, :enabled, :inbox_id,
            :scheduled_at, :campaign_type, :campaign_status,
            :trigger_only_during_business_hours,
            :attachment,
            :template_params, # Permite template_params como escalar (string)
            audience: [[:id, :type, {:id => [], :type => []}], :id, :type], # Aceita formato mais flexível
            trigger_rules: {}
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
