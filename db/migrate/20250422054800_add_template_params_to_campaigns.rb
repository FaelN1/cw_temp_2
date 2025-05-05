class AddTemplateParamsToCampaigns < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:campaigns, :template_params)
      add_column :campaigns, :template_params, :jsonb, default: {}, null: false
    end
  end
end
