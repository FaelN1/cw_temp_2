class AddAttachmentsToCampaigns < ActiveRecord::Migration[6.1]
  def change
    unless table_exists?(:attachments)
      create_table :attachments do |t|
        t.integer :account_id, null: false
        t.string :file_type
        t.string :file_url
        t.integer :file_size
        t.references :attachable, polymorphic: true, null: false

        t.timestamps
      end

      add_index :attachments, :account_id
    end
  end
end
