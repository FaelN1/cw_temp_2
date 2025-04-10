#!/bin/bash
echo "Verificando se as colunas Stripe existem na tabela accounts"
bundle exec rails runner "puts Account.column_names.grep(/stripe/).join(', ')"
echo "Verificando se a conta tem o customer_id definido"
bundle exec rails runner "puts Account.first.stripe_customer_id rescue puts 'Não definido'"
echo "Verificando o status da migração"
bundle exec rails db:migrate:status | grep "add_stripe_fields_to_accounts"
