class Enterprise::Billing::CreateStripeCustomerService
  pattr_initialize [:account!, :plan_name]

  DEFAULT_QUANTITY = 2

  def perform
    customer_id = prepare_customer_id

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
    end
    customer_id
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
    account.administrators.first.email
  end
end
