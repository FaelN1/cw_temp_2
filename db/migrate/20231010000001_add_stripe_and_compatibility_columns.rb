class AddStripeAndCompatibilityColumns < ActiveRecord::Migration[6.1]
  def up
    # Adicionar campos de Stripe na tabela accounts
    unless column_exists?(:accounts, :stripe_customer_id)
      add_column :accounts, :stripe_customer_id, :string
      add_index :accounts, :stripe_customer_id
    end

    unless column_exists?(:accounts, :stripe_price_id)
      add_column :accounts, :stripe_price_id, :string
    end

    unless column_exists?(:accounts, :stripe_subscription_id)
      add_column :accounts, :stripe_subscription_id, :string
      add_index :accounts, :stripe_subscription_id
    end

    # Adicionar campos em attachments
    unless column_exists?(:attachments, :attachable_type)
      add_column :attachments, :attachable_type, :string
      add_column :attachments, :attachable_id, :integer
      add_index :attachments, [:attachable_type, :attachable_id]
    end

    # Adicionar template_params em campaigns
    unless column_exists?(:campaigns, :template_params)
      add_column :campaigns, :template_params, :jsonb, default: {}, null: false
    end

    # Alterar tipos de dados para compatibilidade
    # Verificar se é possível alterar sem problema
    if column_exists?(:messages_corrompidas, :detectado_em)
      # Alterar tipo de timestamp with time zone para without time zone
      change_column :messages_corrompidas, :detectado_em, :timestamp
    end

    # Verificar se existe a tabela messages_corrompidas antes de tentar alterar
    execute <<-SQL
      DO $$
      BEGIN
        IF EXISTS (
          SELECT FROM pg_tables
          WHERE tablename = 'messages_corrompidas'
        ) THEN
          ALTER TABLE messages_corrompidas
          ALTER COLUMN linha_ctid TYPE tid USING linha_ctid::tid;
        END IF;
      EXCEPTION
        WHEN others THEN
          -- Ignorar erros
      END;
      $$;
    SQL
  end

  def down
    # Remover colunas adicionadas
    remove_column :accounts, :stripe_customer_id if column_exists?(:accounts, :stripe_customer_id)
    remove_column :accounts, :stripe_price_id if column_exists?(:accounts, :stripe_price_id)
    remove_column :accounts, :stripe_subscription_id if column_exists?(:accounts, :stripe_subscription_id)

    remove_column :attachments, :attachable_type if column_exists?(:attachments, :attachable_type)
    remove_column :attachments, :attachable_id if column_exists?(:attachments, :attachable_id)

    remove_column :campaigns, :template_params if column_exists?(:campaigns, :template_params)
  end
end
