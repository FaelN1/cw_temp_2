class AccountPolicy < ApplicationPolicy
  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def cache_keys?
    @account_user.administrator? || @account_user.agent?
  end

  def limits?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def update_active_at?
    true
  end

  def subscription?
    @account_user.administrator?
  end

  def checkout?
    @account_user.administrator?
  end

  def administrator?
    @account_user.administrator?
  end

  # Alias para manter compatibilidade se necessário
  alias_method :admin?, :administrator?

  # Método específico para gerenciamento de campanhas
  def manage_campaigns?
    administrator?
  end
end
