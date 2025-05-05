class FixDeleteLabelsFunctionDependencies < ActiveRecord::Migration[7.0]
  def up
    # Remover o trigger que depende da função
    execute <<-SQL
      DROP TRIGGER IF EXISTS after_delete_labels ON labels;
    SQL
  end

  def down
    # Não é necessário recriar o trigger aqui,
    # pois isso será gerenciado pela migração original
  end
end
