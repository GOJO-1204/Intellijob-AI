class JobApplicationsController < ApplicationController
  def update
    @job_application = current_user.job_applications.find(params[:id])
    attrs = params.expect(job_application: %i[status notes])
    return head :unprocessable_entity unless valid_status?(attrs[:status])

    @job_application.update!(attrs)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to matches_path }
    end
  end

  private

  def valid_status?(status)
    status.nil? || JobApplication.statuses.key?(status)
  end
end
