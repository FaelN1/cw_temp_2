class AddBackwardCompatibilityColumns < ActiveRecord::Migration[6.1]
  def change
    # Adicionando colunas ausentes na tabela campaigns
    add_column :campaigns, :failed, :integer, default: 0 unless column_exists?(:campaigns, :failed)
    add_column :campaigns, :it_sent, :integer, default: 0 unless column_exists?(:campaigns, :it_sent)
    add_column :campaigns, :status_send, :integer, default: 0 unless column_exists?(:campaigns, :status_send)

    # Adicionando colunas ausentes na tabela inboxes
    add_column :inboxes, :csat_response_visible, :boolean, default: false unless column_exists?(:inboxes, :csat_response_visible)
    add_column :inboxes, :shot_limit, :integer unless column_exists?(:inboxes, :shot_limit)

    # Criando a tabela campaigns_failed se não existir
    unless table_exists?(:campaigns_failed)
      create_table :campaigns_failed do |t|
        t.integer :campaign_id
        t.text :contact_name
        t.string :phone
      end
    end

    # Criando a tabela messages_corrompidas se não existir
    unless table_exists?(:messages_corrompidas)
      create_table :messages_corrompidas do |t|
        t.text :coluna_erro
        t.timestamp :detectado_em
      end

      # Adicionar a coluna linha_ctid com tipo tid
      execute <<-SQL
        DO $$
        BEGIN
          ALTER TABLE messages_corrompidas ADD COLUMN linha_ctid tid;
        EXCEPTION
          WHEN duplicate_column OR undefined_object OR undefined_column THEN
            -- Ignorar erros se a coluna já existir ou o tipo não for reconhecido
        END;
        $$;
      SQL
    end

    # Criando as tabelas n8n_chat_histories
    unless table_exists?(:n8n_chat_histories_salez)
      create_table :n8n_chat_histories_salez do |t|
        t.jsonb :message
        t.string :session_id
      end
    end

    unless table_exists?(:n8n_chat_histories_squalo)
      create_table :n8n_chat_histories_squalo do |t|
        t.jsonb :message
        t.string :session_id
      end
    end
  end
end
