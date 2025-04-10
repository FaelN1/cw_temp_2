module Enterprise
  class CreateStripeCustomerJob < ApplicationJob
    queue_as :default

    def perform(account, plan_id)
      Rails.logger.info("CreateStripeCustomerJob iniciado com account: #{account.id}, plan_id: #{plan_id.inspect}")

      begin
        # Tente encontrar um administrador na conta ou um SuperAdmin
        admin = account.administrators.first

        if admin.nil?
          admin = ::SuperAdmin.first
          Rails.logger.info("Nenhum administrador encontrado na conta, usando SuperAdmin")
        end

        Rails.logger.info("Admin encontrado: #{admin.inspect}")

        # Verifique se o admin existe
        if admin.nil?
          Rails.logger.error("Nenhum administrador encontrado para a conta #{account.id}")
          return
        end

        # Garanta que o email seja uma string
        admin_email = admin.email.to_s
        Rails.logger.info("Email bruto do administrador: #{admin_email.inspect}")

        # Garanta que o email é válido
        if admin_email.blank? || !admin_email.include?('@')
          Rails.logger.error("Email inválido: #{admin_email}")
          return
        end

        Rails.logger.info("Criando cliente Stripe com email: #{admin_email}")

        # Verificar se a coluna stripe_customer_id existe
        unless account.respond_to?(:stripe_customer_id)
          Rails.logger.error("A coluna stripe_customer_id não existe na tabela accounts. Execute a migração pendente.")
          return
        end

        # Crie o cliente Stripe se ele ainda não existir
        unless account.stripe_customer_id.present?
          customer = Stripe::Customer.create(
            email: admin_email,
            name: account.name,
            metadata: { account_id: account.id }
          )
          account.update!(stripe_customer_id: customer.id)

          # Configurar Boleto como método de pagamento padrão
          Rails.logger.info("Configurando Boleto como método de pagamento padrão para o cliente #{customer.id}")
          configure_boleto_payment_method(customer.id)
        end

        # Verifique se as outras colunas necessárias existem
        unless account.respond_to?(:stripe_subscription_id) && account.respond_to?(:stripe_price_id)
          Rails.logger.error("Colunas de assinatura Stripe não existem na tabela accounts. Execute a migração pendente.")
          return
        end

        # Crie a assinatura se um plano foi especificado
        if plan_id.present?
          Rails.logger.info("Chamando AssignPlanService com plan_id: #{plan_id}")
          result = Enterprise::Billing::AssignPlanService.new(account, plan_id).execute

          # Verificar se a atualização foi bem sucedida
          account.reload
          Rails.logger.info("Após AssignPlanService - customer_id: #{account.stripe_customer_id}")
          Rails.logger.info("Após AssignPlanService - subscription_id: #{account.stripe_subscription_id}")
          Rails.logger.info("Após AssignPlanService - custom_attributes: #{account.custom_attributes}")
        else
          Rails.logger.info("Nenhum plano especificado, apenas cliente criado")
        end
      rescue => e
        Rails.logger.error("Erro no CreateStripeCustomerJob: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        raise e
      end
    end

    private

    def configure_boleto_payment_method(customer_id)
      begin
        # Criar um método de pagamento do tipo boleto
        payment_method = Stripe::PaymentMethod.create({
          type: 'boleto',
          boleto: {
            tax_id: '' # Pode ser preenchido posteriormente pelo cliente
          },
          billing_details: {
            email: '', # Será associado ao cliente
          }
        })

        # Anexar o método de pagamento ao cliente
        Stripe::PaymentMethod.attach(
          payment_method.id,
          { customer: customer_id }
        )

        # Definir como método de pagamento padrão
        Stripe::Customer.update(
          customer_id,
          { invoice_settings: { default_payment_method: payment_method.id } }
        )

        Rails.logger.info("Método de pagamento Boleto configurado com sucesso para o cliente #{customer_id}")
      rescue => e
        Rails.logger.error("Erro ao configurar método de pagamento Boleto: #{e.message}")
        # Continuamos o fluxo mesmo se falhar a configuração do boleto
      end
    end
  end
end
