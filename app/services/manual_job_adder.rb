# Adds a job the user applied to elsewhere. Returns {application:, error:}.
class ManualJobAdder
  STATUSES = %w[saved applied interview offer rejected].freeze
  MAX_TEXT = 200
  MAX_URL = 2000

  def self.call(user, attrs)
    values = clean(attrs)
    error = validate(values)
    return { application: nil, error: error } if error

    save(user, values)
  end

  def self.clean(attrs)
    attrs = attrs.to_h.with_indifferent_access
    %i[title company url location status].index_with { |key| attrs[key].to_s.strip }
  end

  def self.validate(values)
    return "Enter a job title." if values[:title].blank?
    return "Enter a company." if values[:company].blank?
    return "Enter a link that starts with http:// or https://." unless valid_url?(values[:url])
    return "Choose a status from the list." unless STATUSES.include?(values[:status])
    return "Title, company or location is too long." if too_long?(values)

    nil
  end

  def self.too_long?(values)
    values.values_at(:title, :company, :location).any? { |text| text.length > MAX_TEXT }
  end

  def self.valid_url?(url)
    return false if url.blank? || url.length > MAX_URL

    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def self.save(user, values)
    application = nil
    ActiveRecord::Base.transaction do
      job = Job.find_or_create_by!(url: values[:url]) do |new_job|
        new_job.assign_attributes(title: values[:title], company: values[:company],
                                  location: values[:location].presence, source: "manual")
      end
      application = user.job_applications.create!(job: job, status: values[:status])
    end
    { application: application, error: nil }
  rescue ActiveRecord::RecordInvalid
    { application: nil, error: "You already have this job in your list." }
  rescue ActiveRecord::RecordNotUnique
    { application: nil, error: "Could not save this job. Try again." }
  end
  private_class_method :clean, :validate, :too_long?, :valid_url?, :save
end
