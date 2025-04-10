module Enterprise::Concerns::AccountUserStripeConcern
  extend ActiveSupport::Concern

  included do
    after_create :setup_stripe_for_account
  end

  private

  def setup_stripe_for_account
    Rails.logger.info "setup_stripe_for_account chamado para AccountUser ID: #{id}, role: #{role}"

    return unless role == 'administrator'

    account = self.account
    Rails.logger.info "Account: #{account.inspect}"
    Rails.logger.info "Custom attributes: #{account.custom_attributes.inspect}"

    return unless account.custom_attributes['pending_stripe_setup'] == true

    # Verificar se é o primeiro administrador
    if account.account_users.where(role: :administrator).count == 1
      Rails.logger.info "Primeiro administrador detectado para a conta #{account.id}"

      # Remover flag de pendência
      account.update(custom_attributes: account.custom_attributes.merge({
        pending_stripe_setup: false
      }))

      Rails.logger.info "pending_stripe_setup definido como false para a conta #{account.id}"

      # Agendar criação do cliente Stripe
      selected_plan = account.custom_attributes['selected_plan']
      Enterprise::CreateStripeCustomerJob.perform_later(account, selected_plan)
      Rails.logger.info "Job Enterprise::CreateStripeCustomerJob enfileirado para a conta #{account.id}"
    else
      Rails.logger.info "Não é o primeiro administrador para a conta #{account.id}"
    end
  end
end
