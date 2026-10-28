class DashboardController < ApplicationController
  DEFAULT_TAB = "saved".freeze

  def show
    @tabs = tabs
    @tab = tab_from(params[:status])
    @counts = DashboardStats.call(current_user)[:counts]
    @applications = current_user.job_applications.where(status: @tab)
                                .includes(:job).order(updated_at: :desc)
  end

  private

  def tabs
    JobApplication.statuses.keys - %w[matched]
  end

  def tab_from(value)
    tabs.include?(value.to_s) ? value.to_s : DEFAULT_TAB
  end
end
