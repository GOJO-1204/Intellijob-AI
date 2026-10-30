require "test_helper"

class GeminiClientTest < ActiveSupport::TestCase
  URL = "https://example.test/gemini".freeze

  def reply(klass, code, body = "")
    klass.new("1.1", code, "").tap { |res| res.define_singleton_method(:body) { body } }
  end

  def ok = reply(Net::HTTPOK, "200", "answer")
  def unavailable = reply(Net::HTTPServiceUnavailable, "503")

  # Replaces Net::HTTP.start with a list of answers (a response or an exception class).
  def with_replies(replies)
    original = Net::HTTP.method(:start)
    calls = 0
    Net::HTTP.define_singleton_method(:start) do |*_args, **_opts, &_block|
      item = replies[calls]
      calls += 1
      raise item if item.is_a?(Class)

      item
    end
    yield -> { calls }
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  test "returns the body on success" do
    with_replies([ ok ]) do |calls|
      assert_equal "answer", GeminiClient.call(URL, {}, delays: [ 0, 0 ])
      assert_equal 1, calls.call
    end
  end

  test "retries after a 503 and then succeeds" do
    with_replies([ unavailable, ok ]) do |calls|
      assert_equal "answer", GeminiClient.call(URL, {}, delays: [ 0, 0 ])
      assert_equal 2, calls.call
    end
  end

  test "retries after a timeout and then succeeds" do
    with_replies([ Net::ReadTimeout, ok ]) do |calls|
      assert_equal "answer", GeminiClient.call(URL, {}, delays: [ 0, 0 ])
      assert_equal 2, calls.call
    end
  end

  test "gives up after three 503 answers" do
    with_replies([ unavailable, unavailable, unavailable, ok ]) do |calls|
      error = assert_raises(GeminiClient::Error) { GeminiClient.call(URL, {}, delays: [ 0, 0 ]) }
      assert_equal "503", error.code
      assert_equal 3, calls.call
    end
  end

  test "does not retry a 400 or a 429" do
    [ [ Net::HTTPBadRequest, "400" ], [ Net::HTTPTooManyRequests, "429" ] ].each do |klass, code|
      with_replies([ reply(klass, code), ok ]) do |calls|
        error = assert_raises(GeminiClient::Error) { GeminiClient.call(URL, {}, delays: [ 0, 0 ]) }
        assert_equal code, error.code
        assert_equal 1, calls.call
      end
    end
  end
end
