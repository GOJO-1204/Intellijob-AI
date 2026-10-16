require "net/http"
require "json"

module JobSources
  class Remotive
    URL = URI("https://remotive.com/api/remote-jobs")
    def self.fetch
      response = Net::HTTP.start(URL.host, URL.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
        http.get(URL.request_uri)
      end
      return failed("HTTP #{response.code}") unless response.code == "200"
      jobs = JSON.parse(response.body)["jobs"]
      return failed("missing 'jobs' key") unless jobs.is_a?(Array)
      jobs.filter_map { |job| build(job) }
    rescue StandardError => e
      failed("#{e.class}: #{e.message}")
    end

    def self.build(job)
      return if job["url"].to_s.strip.empty?
      { title: job["title"], company: job["company_name"], url: job["url"],
        description: job["description"], location: job["candidate_required_location"],
        remote: true, salary_min: nil, source: "remotive", external_id: job["id"].to_s,
        posted_at: parse_time(job["publication_date"]) }
    end

    def self.parse_time(value)
      Time.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.failed(reason)
      Rails.logger.warn("[JobSources::Remotive] #{reason}")
      []
    end
    private_class_method :build, :parse_time, :failed
  end
end
