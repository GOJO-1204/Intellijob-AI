module RateLimitedResponse
  extend ActiveSupport::Concern

  private

  # Plain page with status 429, used by the with: option of rate_limit.
  def rate_limited(message)
    @message = message
    render "shared/rate_limited", status: :too_many_requests
  end
end
