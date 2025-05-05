json.auto_resolve_duration resource.auto_resolve_duration
json.created_at resource.created_at
if resource.custom_attributes.present?
  json.custom_attributes do
    # Plano e informações de faturamento
    json.plan_name resource.custom_attributes['plan_name']
    json.selected_plan resource.custom_attributes['selected_plan']
    json.subscribed_quantity resource.custom_attributes['subscribed_quantity']
    json.subscription_status resource.custom_attributes['subscription_status']
    json.subscription_ends_on resource.custom_attributes['subscription_ends_on']
    json.has_payment_method resource.custom_attributes['has_payment_method']

    # Outros atributos customizados
    json.industry resource.custom_attributes['industry'] if resource.custom_attributes['industry'].present?
    json.company_size resource.custom_attributes['company_size'] if resource.custom_attributes['company_size'].present?
    json.timezone resource.custom_attributes['timezone'] if resource.custom_attributes['timezone'].present?
    json.logo resource.custom_attributes['logo'] if resource.custom_attributes['logo'].present?
    json.onboarding_step resource.custom_attributes['onboarding_step'] if resource.custom_attributes['onboarding_step'].present?
  end
end

# Informações de faturamento do Stripe
json.stripe_customer_id resource.stripe_customer_id
json.stripe_subscription_id resource.stripe_subscription_id
json.stripe_price_id resource.stripe_price_id
json.billing_status resource.respond_to?(:billing_status) ? resource.billing_status : nil

json.domain @account.domain
json.features @account.enabled_features
json.id @account.id
json.locale @account.locale
json.name @account.name
json.support_email @account.support_email
json.status @account.status
json.cache_keys @account.cache_keys
