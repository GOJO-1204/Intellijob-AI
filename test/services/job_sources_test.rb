require "test_helper"

class JobSourcesTest < ActiveSupport::TestCase
  test "all returns Remotive and Adzuna in that order" do
    assert_equal [ JobSources::Remotive, JobSources::Adzuna ], JobSources.all
  end

  test "every source responds to fetch" do
    assert(JobSources.all.all? { |source| source.respond_to?(:fetch) })
  end
end
