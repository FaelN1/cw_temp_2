class AddStripeFieldsToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :stripe_customer_id, :string
    add_column :accounts, :stripe_subscription_id, :string
    add_column :accounts, :stripe_price_id, :string
    add_index :accounts, :stripe_customer_id
    add_index :accounts, :stripe_subscription_id
  end
end
