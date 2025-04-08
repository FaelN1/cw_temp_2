class Enterprise::CreateStripeCustomerJob < ApplicationJob
  queue_as :default

  def perform(account, plan_name = nil)
    Enterprise::Billing::CreateStripeCustomerService.new(account: account, plan_name: plan_name).perform
  end
end
