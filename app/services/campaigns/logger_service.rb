module Campaigns
  class LoggerService
    def self.log_campaign_creation(campaign_params)
      Rails.logger.info("=== TENTATIVA DE CRIAÇÃO DE CAMPANHA ===")
      Rails.logger.info("Parâmetros recebidos: #{campaign_params.inspect}")

      if campaign_params[:inbox_id].present?
        inbox = Inbox.find_by(id: campaign_params[:inbox_id])
        if inbox
          Rails.logger.info("Inbox encontrada - ID: #{inbox.id}, Tipo: #{inbox.channel_type}")
        else
          Rails.logger.error("Inbox não encontrada com ID: #{campaign_params[:inbox_id]}")
        end
      else
        Rails.logger.error("Parâmetro inbox_id não fornecido")
      end
    end

    def self.log_campaign_error(error)
      Rails.logger.error("=== ERRO NA CRIAÇÃO DE CAMPANHA ===")
      Rails.logger.error("Mensagem de erro: #{error.message}")
      Rails.logger.error("Backtrace: #{error.backtrace.join("\n")}")
    end
  end
end
