class CreateScheduledMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :scheduled_messages, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.datetime :scheduled_at, null: false
      t.string :status, default: 'pending'
      t.timestamps
    end

    add_index :scheduled_messages, :scheduled_at, if_not_exists: true
    add_index :scheduled_messages, :status, if_not_exists: true
  end
end
