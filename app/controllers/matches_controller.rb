class MatchesController < ApplicationController
  def index
    @applications = current_user.job_applications.matched
                                .includes(:job)
                                .order(Arel.sql("job_applications.score DESC NULLS LAST"))
  end
end
