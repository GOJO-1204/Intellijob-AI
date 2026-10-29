class JobApplicationsController < ApplicationController
  def new
    @form = {}
  end

  def create
    result = ManualJobAdder.call(current_user, manual_params)
    if result[:error]
      @form = manual_params
      @error = result[:error]
      render :new, status: :unprocessable_entity
    else
      redirect_to dashboard_path(status: result[:application].status), notice: "Job added."
    end
  end

  def update
    @job_application = current_user.job_applications.find(params[:id])
    attrs = params.expect(job_application: %i[status notes])
    return head :unprocessable_entity unless valid_status?(attrs[:status])

    saved = @job_application.update(attrs)
    respond_to do |format|
      format.turbo_stream { render status: (saved ? :ok : :unprocessable_entity) }
      format.html do
        saved ? redirect_back_or_to(matches_path) : head(:unprocessable_entity)
      end
    end
  end

  private

  def manual_params
    params.fetch(:job, {}).permit(:title, :company, :url, :location, :status).to_h
  end

  def valid_status?(status)
    status.nil? || JobApplication.statuses.key?(status)
  end
end
