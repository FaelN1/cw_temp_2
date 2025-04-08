class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  # def scoped_resource
  #   if current_user.super_admin?
  #     resource_class
  #   else
  #     resource_class.with_less_stuff
  #   end
  # end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def resource_params
    # Extrair parâmetros da conta do namespace "account"
    account_params = params[:account] || {}

    # Processar os limites para remover valores vazios
    limits = {}
    if account_params[:limits].present?
      limits = account_params[:limits].transform_values do |v|
        v.present? ? v : nil
      end.compact
    end

    # Criar parâmetros permitidos com valores dos campos recebidos
    permitted_params = ActionController::Parameters.new(
      name: account_params[:name],
      locale: account_params[:locale],
      status: account_params[:status],
      limits: limits
    ).permit!

    # Processar feature flags selecionadas
    if params[:enabled_features].present?
      permitted_params[:selected_feature_flags] = params[:enabled_features].keys.map(&:to_sym)
    end

    # Processar plano selecionado
    if account_params[:selected_plan].present?
      permitted_params[:custom_attributes] = {
        'selected_plan' => account_params[:selected_plan]
      }
    end

    Rails.logger.info("Parâmetros finais: #{permitted_params.inspect}")
    permitted_params
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def create
    Rails.logger.info("Account Creation Params: #{params.inspect}")
    resource = resource_class.new(resource_params)

    Rails.logger.info("Resource Params Processed: #{resource_params.inspect}")
    Rails.logger.info("New Account Object: #{resource.inspect}")

    authorize_resource(resource)

    if resource.save
      Rails.logger.info("Account saved successfully with ID: #{resource.id}")

      # Processamento do plano selecionado
      if params[:account] && params[:account][:selected_plan].present?
        plan_name = params[:account][:selected_plan]
        Rails.logger.info("Selected Plan: #{plan_name}")

        # Iniciar job para criar cliente Stripe com o plano selecionado
        Enterprise::CreateStripeCustomerJob.perform_later(resource, plan_name)

        Rails.logger.info("Plan processing completed for account #{resource.id}")
      end

      redirect_to(
        [namespace, resource],
        notice: translate_with_resource("create.success")
      )
    else
      Rails.logger.error("Account creation failed: #{resource.errors.full_messages.join(', ')}")
      render :new, locals: {
        page: Administrate::Page::Form.new(dashboard, resource)
      }, status: :unprocessable_entity
    end
  end
end
