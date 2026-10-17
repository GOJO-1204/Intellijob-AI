require "net/http"
require "json"

module JobSources
  class Adzuna
    COUNTRY = "in"
    KEYWORDS = [ "ruby on rails", "software developer", "python developer" ].freeze
    BASE_URL = "https://api.adzuna.com/v1/api/jobs/#{COUNTRY}/search/1"
    REMOTE = /\bremote\b|work from home/i

    def self.fetch
      app_id = Rails.application.credentials.dig(:adzuna, :app_id)
      app_key = Rails.application.credentials.dig(:adzuna, :app_key)
      return failed("missing Adzuna credentials") if app_id.to_s.strip.empty? || app_key.to_s.strip.empty?
      KEYWORDS.flat_map { |keyword| fetch_keyword(keyword, app_id, app_key) }.uniq { |job| job[:url] }
    end

    def self.fetch_keyword(keyword, app_id, app_key)
      uri = URI(BASE_URL)
      uri.query = URI.encode_www_form(app_id: app_id, app_key: app_key, results_per_page: 50,
                                      what: keyword, "content-type": "application/json")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
        http.get(uri.request_uri)
      end
      return failed("HTTP #{response.code}", keyword) unless response.code == "200"
      results = JSON.parse(response.body)["results"]
      return failed("missing 'results' key", keyword) unless results.is_a?(Array)
      results.filter_map { |result| build(result) }
    rescue StandardError => e
      failed(e.class.to_s, keyword) # class only: exception messages could echo the URL
    end

    def self.build(job)
      return unless job.is_a?(Hash) && !job["redirect_url"].to_s.strip.empty?
      { title: job["title"], company: job.dig("company", "display_name"), url: job["redirect_url"],
        description: job["description"], location: job.dig("location", "display_name"),
        remote: "#{job['title']} #{job['description']}".match?(REMOTE),
        salary_min: job["salary_min"].is_a?(Numeric) ? job["salary_min"].round : nil,
        source: "adzuna", external_id: job["id"].to_s, posted_at: parse_time(job["created"]) }
    end

    def self.parse_time(value)
      Time.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.failed(reason, keyword = nil)
      Rails.logger.warn("[JobSources::Adzuna] #{[ keyword, reason ].compact.join(': ')}")
      []
    end
    private_class_method :fetch_keyword, :build, :parse_time, :failed
  end
end
