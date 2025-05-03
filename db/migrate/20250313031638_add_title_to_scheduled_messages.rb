class AddTitleToScheduledMessages < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:scheduled_messages, :title)
      add_column :scheduled_messages, :title, :string
    end
  end
end
