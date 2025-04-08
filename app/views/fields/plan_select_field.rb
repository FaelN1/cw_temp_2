require "administrate/field/base"

class PlanSelectField < Administrate::Field::Base
  def to_s
    data
  end

  def plans_for_select
    installation_config = InstallationConfig.find_by(name: 'CHATWOOT_CLOUD_PLANS')
    plans = installation_config&.value || []

    # Retorna um array de arrays no formato [nome_do_plano, id_do_plano]
    plans.map { |plan| [plan['name'], plan['name']] }
  end
end
