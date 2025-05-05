json.id resource.id
json.name resource.name
json.locale resource.locale
json.domain resource.domain
json.support_email resource.support_email
json.auto_resolve_duration resource.auto_resolve_duration
json.features resource.enabled_features
json.limits resource.limits
json.custom_attributes resource.custom_attributes || {}

# Campos relacionados ao Stripe
json.stripe_customer_id resource.stripe_customer_id
json.stripe_subscription_id resource.stripe_subscription_id
json.stripe_price_id resource.stripe_price_id
json.billing_status resource.billing_status.to_i

json.domain @account.domain if @account.present?
json.features @account.enabled_features if @account.present?
