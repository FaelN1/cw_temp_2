class AddStripeFieldsToAccounts < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:accounts, :stripe_customer_id)
      add_column :accounts, :stripe_customer_id, :string
    end

    unless column_exists?(:accounts, :stripe_subscription_id)
      add_column :accounts, :stripe_subscription_id, :string
    end

    unless column_exists?(:accounts, :stripe_price_id)
      add_column :accounts, :stripe_price_id, :string
    end

    unless column_exists?(:accounts, :billing_status)
      add_column :accounts, :billing_status, :integer, default: 0
    end
  end
end
