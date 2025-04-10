module Enterprise
  class AccountsController < ApplicationController
    def checkout
      account_id = params[:account_id]
      account = Account.find(account_id)

      if account.stripe_customer_id.present?
        begin
          session = Stripe::BillingPortal::Session.create({
            customer: account.stripe_customer_id,
            return_url: "#{request.base_url}/app/accounts/#{account_id}/settings/billing"
          })
          redirect_to session.url, allow_other_host: true
        rescue => e
          flash[:error] = "Erro ao criar sessão no portal de faturamento: #{e.message}"
          redirect_to "/app/accounts/#{account_id}/settings/billing"
        end
      else
        flash[:error] = "Esta conta não tem um cliente Stripe associado."
        redirect_to "/app/accounts/#{account_id}/settings/billing"
      end
    end
  end
end
