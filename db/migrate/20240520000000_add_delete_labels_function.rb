class AddDeleteLabelsFunction < ActiveRecord::Migration[7.0]
  def up
    # Primeiro, verificamos se a função existe e a removemos se necessário
    execute(<<-SQL)
      DO $$
      BEGIN
        IF EXISTS (
          SELECT FROM pg_proc
          WHERE proname = 'delete_labels_from_tags_and_taggings'
        ) THEN
          DROP FUNCTION delete_labels_from_tags_and_taggings();
        END IF;
      END $$;
    SQL

    # Agora criamos a função de forma segura
    execute(<<-SQL)
      CREATE OR REPLACE FUNCTION delete_labels_from_tags_and_taggings() RETURNS void AS $$
      BEGIN
        -- Delete all tags related to labels
        DELETE FROM taggings
        WHERE tag_id IN (
          SELECT id FROM tags
          WHERE tags.name LIKE 'label:%'
        );

        -- Delete the label tags themselves
        DELETE FROM tags
        WHERE tags.name LIKE 'label:%';

        RETURN;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute("DROP FUNCTION IF EXISTS delete_labels_from_tags_and_taggings();")
  end
end
