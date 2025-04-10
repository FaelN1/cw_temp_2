class Enterprise::Api::V1::AccountsController < Api::BaseController
  include BillingHelper
  before_action :fetch_account
  before_action :check_authorization
  before_action :check_cloud_env, only: [:limits]

  # Certifique-se de que este método retorne dados úteis e não cause redirecionamentos
  def subscription
    account_id = params[:id]
    account = Account.find(account_id)

    render json: {
      stripe_customer_id: account.stripe_customer_id,
      stripe_subscription_id: account.stripe_subscription_id,
      stripe_price_id: account.stripe_price_id,
      custom_attributes: account.custom_attributes
    }
  end

  def limits
    limits = {
      'conversation' => {},
      'non_web_inboxes' => {}
    }

    if default_plan?(@account)
      limits = {
        'conversation' => {
          'allowed' => 500,
          'consumed' => conversations_this_month(@account)
        },
        'non_web_inboxes' => {
          'allowed' => 0,
          'consumed' => non_web_inboxes(@account)
        }
      }
    end

    # include id in response to ensure that the store can be updated on the frontend
    render json: { id: @account.id, limits: limits }, status: :ok
  end

  def checkout
    return create_stripe_billing_session(stripe_customer_id) if stripe_customer_id.present?

    render_invalid_billing_details
  end

  def check_cloud_env
    installation_config = InstallationConfig.find_by(name: 'DEPLOYMENT_ENV')
    render json: { error: 'Not found' }, status: :not_found unless installation_config&.value == 'cloud'
  end

  private

  def fetch_account
    @account = current_user.accounts.find(params[:id])
    @current_account_user = @account.account_users.find_by(user_id: current_user.id)
  end

  def stripe_customer_id
    @account.custom_attributes['stripe_customer_id']
  end

  def render_invalid_billing_details
    render_could_not_create_error('Please subscribe to a plan before viewing the billing details')
  end

  def create_stripe_billing_session(customer_id)
    session = Enterprise::Billing::CreateSessionService.new.create_session(customer_id)
    render_redirect_url(session.url)
  end

  def render_redirect_url(redirect_url)
    render json: { redirect_url: redirect_url }
  end

  def pundit_user
    {
      user: current_user,
      account: @account,
      account_user: @current_account_user
    }
  end
end
