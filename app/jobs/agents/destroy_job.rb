# frozen_string_literal: true

class Agents::DestroyJob < ApplicationJob
  queue_as :low

  def perform(agent_id, performed_by)
    ActiveRecord::Base.transaction do
      @agent = User.find_by(id: agent_id)
      return if @agent.blank?

      send_notification(@agent, performed_by)
      remove_user_from_teams
      destroy_notification_setting(@agent)
      @agent.destroy!
    end
  end

  private

  def send_notification(agent, performed_by)
    # ...existing code...
  end

  def destroy_notification_setting(agent)
    return unless agent&.id

    notification_setting = NotificationSetting.find_by(user_id: agent.id)
    notification_setting&.destroy!
  end

  # Remove o usuário das equipes sem usar a variável 'account'
  def remove_user_from_teams
    return unless @agent

    @agent.account_users.each do |account_user|
      account_id = account_user.account_id
      teams = Team.where(account_id: account_id)

      TeamMember.where(user_id: @agent.id, team_id: teams.pluck(:id)).destroy_all
    end
  end
end
