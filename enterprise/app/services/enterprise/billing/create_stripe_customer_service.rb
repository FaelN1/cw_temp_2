class Enterprise::Billing::CreateStripeCustomerService
  pattr_initialize [:account!, :plan_name]

  DEFAULT_QUANTITY = 2

  def perform
    customer_id = prepare_customer_id

    # Configurar Boleto como método de pagamento padrão se o cliente foi recém-criado
    if @customer_created
      configure_boleto_payment_method(customer_id)
    end

    # Usar o plano especificado ou o plano padrão
    plan = find_plan(plan_name) || default_plan

    subscription = Stripe::Subscription.create(
      {
        customer: customer_id,
        items: [{ price: price_id_for_plan(plan), quantity: quantity_for_plan(plan) }],
        collection_method: 'send_invoice',
        days_until_due: 30
      }
    )

    # Manter os custom_attributes existentes e adicionar os novos
    existing_attrs = account.custom_attributes || {}

    account.update!(
      custom_attributes: existing_attrs.merge(
        {
          stripe_customer_id: customer_id,
          stripe_price_id: subscription['plan']['id'],
          stripe_product_id: subscription['plan']['product'],
          plan_name: plan['name'],
          selected_plan: plan['name'], # Manter ambos para consistência
          subscribed_quantity: subscription['quantity']
        }
      )
    )
  end

  private

  def prepare_customer_id
    customer_id = account.custom_attributes['stripe_customer_id']
    if customer_id.blank?
      customer = Stripe::Customer.create({ name: account.name, email: billing_email })
      customer_id = customer.id
      @customer_created = true
    else
      @customer_created = false
    end
    customer_id
  end

  def configure_boleto_payment_method(customer_id)
    begin
      # Criar um método de pagamento do tipo boleto
      payment_method = Stripe::PaymentMethod.create({
        type: 'boleto',
        boleto: {
          tax_id: '' # Pode ser preenchido posteriormente pelo cliente
        },
        billing_details: {
          email: billing_email,
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

    rescue => e
      Rails.logger.error("Erro ao configurar método de pagamento Boleto: #{e.message}")
      # Continuamos o fluxo mesmo se falhar a configuração do boleto
    end
  end

  def find_plan(plan_name)
    return nil unless plan_name

    installation_config = InstallationConfig.find_by(name: 'CHATWOOT_CLOUD_PLANS')
    plans = installation_config&.value || []
    plans.find { |p| p['name'] == plan_name }
  end

  def quantity_for_plan(plan)
    plan['default_quantity'] || DEFAULT_QUANTITY
  end

  def default_plan
    installation_config = InstallationConfig.find_by(name: 'CHATWOOT_CLOUD_PLANS')
    @default_plan ||= installation_config&.value&.first
  end

  def price_id_for_plan(plan)
    price_ids = plan['price_ids']
    price_ids.first
  end

  def billing_email
    email = account.users.find_by(account_users: { role: 'administrator' })&.email

    # Extrair apenas o endereço de email se estiver no formato "Nome <email>"
    if email.present? && email.include?('<') && email.include?('>')
      email = email.match(/<(.+)>/)[1]
    end

    email || "account-#{account.id}@placeholder.chatwoot.com"
  end
end
