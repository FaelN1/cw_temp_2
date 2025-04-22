class AddTemplateParamsToCampaigns < ActiveRecord::Migration[6.1]
  def change
    add_column :campaigns, :template_params, :jsonb, default: {}, null: false
  end
end
