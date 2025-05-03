class AddExternalTokenToInboxes < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:inboxes, :external_token)
      add_column :inboxes, :external_token, :string
    end
  end
end
