require "net/http"

class GeminiClient
  class Error < StandardError
    attr_reader :code, :retryable

    def initialize(message, code: nil, retryable: false)
      super(message)
      @code = code
      @retryable = retryable
    end
  end

  DELAYS = [ 2, 4 ].freeze

  def self.call(url, payload, delays: DELAYS)
    attempt = 0
    begin
      attempt += 1
      request(url, payload)
    rescue Error => e
      log(e, attempt)
      raise unless e.retryable && attempt <= delays.size

      sleep(delays[attempt - 1])
      retry
    end
  end

  def self.request(url, payload)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    req["x-goog-api-key"] = Rails.application.credentials.dig(:gemini, :api_key)
    req.body = payload.to_json
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 30) { |h| h.request(req) }
    return res.body if res.is_a?(Net::HTTPSuccess)

    raise Error.new("HTTP #{res.code}", code: res.code, retryable: res.code == "503")
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error.new("Timeout", code: "timeout", retryable: true)
  end

  def self.log(error, attempt)
    Rails.logger.warn("GeminiClient attempt #{attempt} failed: #{error.message}")
  end

  private_class_method :request, :log
end
