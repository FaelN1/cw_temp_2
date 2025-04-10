module Enterprise::Billing
  class AssignPlanService
    def initialize(account, plan_id)
      @account = account
      @plan_id = plan_id
      Rails.logger.info("AssignPlanService iniciado com plan_id: #{plan_id.inspect}")
    end

    def execute
      @price_id = convert_plan_name_to_price_id
      Rails.logger.info("Tentando criar assinatura com price_id final: #{@price_id}")

      # Não tente criar uma assinatura se o price_id for nil
      unless @price_id
        Rails.logger.error("Não foi possível obter price_id para o plano #{@plan_id}. Verifique a configuração CHATWOOT_CLOUD_PLANS.")
        return
      end

      # Obtenha a quantidade do plano ou use um valor padrão
      plan_config = find_plan_config
      quantity = plan_config&.dig('default_quantity') || 1

      begin
        # Crie a assinatura com os parâmetros obrigatórios do Stripe
        subscription = Stripe::Subscription.create({
          customer: @account.stripe_customer_id,
          items: [
            {
              price: @price_id,
              quantity: 1
            }
          ],
          trial_period_days: 30 # Adiciona período de avaliação de 30 dias
        })

        Rails.logger.info("Assinatura criada com sucesso: #{subscription.id}")

        # Salvar os dados da assinatura diretamente na conta
        if @account.respond_to?(:stripe_subscription_id=)
          @account.stripe_subscription_id = subscription.id
          @account.stripe_price_id = @price_id
          Rails.logger.info("Campos stripe definidos diretamente: subscription_id=#{subscription.id}, price_id=#{@price_id}")
        end

        # Adicionar campos ao custom_attributes também (redundância intencional para compatibilidade)
        current_attrs = @account.custom_attributes || {}
        current_attrs['stripe_price_id'] = @price_id
        current_attrs['stripe_current_period_end'] = subscription.current_period_end
        current_attrs['stripe_subscription_id'] = subscription.id
        @account.custom_attributes = current_attrs

        # Salvar as alterações
        if @account.save
          Rails.logger.info("Conta atualizada com sucesso: subscription_id=#{@account.stripe_subscription_id}, price_id=#{@account.custom_attributes['stripe_price_id']}")
        else
          Rails.logger.error("Falha ao salvar a conta: #{@account.errors.full_messages.join(', ')}")
        end

        return subscription
      rescue => e
        Rails.logger.error("Erro ao criar assinatura: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        raise e
      end
    end

    private

    def convert_plan_name_to_price_id
      begin
        cloud_plans = if ENV.fetch('CHATWOOT_CLOUD_PLANS', '[]').is_a?(String)
                        JSON.parse(ENV.fetch('CHATWOOT_CLOUD_PLANS', '[]'))
                      else
                        ENV.fetch('CHATWOOT_CLOUD_PLANS', [])
                      end

        Rails.logger.info("CHATWOOT_CLOUD_PLANS parseado: #{cloud_plans.inspect}")

        plan = cloud_plans.find { |p| p['name'] == @plan_id }
        unless plan
          Rails.logger.error("Plano não encontrado: #{@plan_id}")
          return nil
        end

        # Se price_ids for um array, use o primeiro elemento
        price_id = if plan['price_ids'].is_a?(Array)
                     plan['price_ids'].first
                   else
                     plan['price_ids']
                   end

        Rails.logger.info("Plano encontrado: #{plan.inspect}, Price ID: #{price_id}")
        price_id
      rescue JSON::ParserError => e
        Rails.logger.error("Erro ao analisar CHATWOOT_CLOUD_PLANS: #{e.message}")
        nil
      end
    end

    def find_plan_config
      begin
        cloud_plans = if ENV.fetch('CHATWOOT_CLOUD_PLANS', '[]').is_a?(String)
                        JSON.parse(ENV.fetch('CHATWOOT_CLOUD_PLANS', '[]'))
                      else
                        ENV.fetch('CHATWOOT_CLOUD_PLANS', [])
                      end

        cloud_plans.find { |p| p['name'] == @plan_id }
      rescue JSON::ParserError
        nil
      end
    end
  end
end
