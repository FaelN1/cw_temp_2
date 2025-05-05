class AddPolymorphicToAttachments < ActiveRecord::Migration[6.1]
  def up
    # Adicionar colunas para relações polimórficas
    add_column :attachments, :attachable_type, :string, null: true unless column_exists?(:attachments, :attachable_type)
    add_column :attachments, :attachable_id, :integer, null: true unless column_exists?(:attachments, :attachable_id)

    # Criar índice para consultas eficientes
    unless index_exists?(:attachments, [:attachable_type, :attachable_id])
      add_index :attachments, [:attachable_type, :attachable_id]
    end

    # Tornar message_id opcional para permitir outros tipos de associação
    change_column_null :attachments, :message_id, true

    # Opcionalmente, migrar dados existentes para o novo formato
    execute <<-SQL
      UPDATE attachments
      SET attachable_type = 'Message', attachable_id = message_id
      WHERE message_id IS NOT NULL AND (attachable_type IS NULL OR attachable_id IS NULL)
    SQL
  end

  def down
    # Verificar se existem attachments não relacionados a mensagens
    if Attachment.where(message_id: nil).exists?
      raise ActiveRecord::IrreversibleMigration, "Não é possível reverter porque existem attachments não relacionados a mensagens"
    end

    remove_column :attachments, :attachable_type
    remove_column :attachments, :attachable_id
    remove_index :attachments, [:attachable_type, :attachable_id], if_exists: true
    change_column_null :attachments, :message_id, false
  end
end
