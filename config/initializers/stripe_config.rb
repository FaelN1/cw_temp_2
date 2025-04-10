# Configura a chave da API Stripe
Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', '')

# Configura planos padrão se CHATWOOT_CLOUD_PLANS não estiver definido ou for inválido
unless ENV['CHATWOOT_CLOUD_PLANS'].present? && ENV['CHATWOOT_CLOUD_PLANS'] != '[]'
  default_plans = [
    {
      'name' => 'Pro',
      'default_quantity' => 10,
      'product_id' => 'prod_RpWZqcSx3tExrW',
      'price_ids' => 'price_1QvrWfGnu5TnL43dhMmwjvST'
    }
  ]

  ENV['CHATWOOT_CLOUD_PLANS'] = default_plans.to_json
  Rails.logger.info("CHATWOOT_CLOUD_PLANS configurado com valores padrão: #{ENV['CHATWOOT_CLOUD_PLANS']}")
end
