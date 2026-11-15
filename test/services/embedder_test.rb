require "test_helper"

class EmbedderTest < ActiveSupport::TestCase
  VECTOR = [ 0.1, 0.2, 0.3 ].freeze

  def fake_pipeline(calls)
    lambda do |text, **options|
      calls << [ text, options ]
      VECTOR
    end
  end

  # Puts a pipeline into Embedder's @pipeline and always restores the old value.
  def with_pipeline(pipeline)
    original = Embedder.instance_variable_get(:@pipeline)
    Embedder.instance_variable_set(:@pipeline, pipeline)
    yield
  ensure
    Embedder.instance_variable_set(:@pipeline, original)
  end

  # Replaces Informers.pipeline so the real model can never load. Yields the list of calls.
  def with_informers(fake)
    loads = []
    original = Informers.method(:pipeline)
    Informers.define_singleton_method(:pipeline) do |*args, **_options|
      loads << args
      fake
    end
    yield loads
  ensure
    Informers.define_singleton_method(:pipeline, original)
  end

  def passed_text(text)
    calls = []
    with_pipeline(fake_pipeline(calls)) { Embedder.call(text) }
    calls.first.first
  end

  test "blank text raises ArgumentError before the model is used" do
    calls = []
    with_pipeline(fake_pipeline(calls)) do
      [ nil, "", "   ", "\n\t" ].each do |text|
        error = assert_raises(ArgumentError) { Embedder.call(text) }
        assert_equal "text is blank", error.message
      end
    end
    assert_empty calls
  end

  test "returns exactly what the pipeline returned" do
    result = nil
    with_pipeline(fake_pipeline([])) { result = Embedder.call("hello") }
    assert_same VECTOR, result
  end

  test "passes mean pooling and normalize to the pipeline" do
    calls = []
    with_pipeline(fake_pipeline(calls)) { Embedder.call("hello") }
    assert_equal 1, calls.size
    assert_equal "hello", calls.first.first
    assert_equal({ pooling: "mean", normalize: true }, calls.first.last)
  end

  test "text longer than 2000 characters is cut to the first 2000" do
    text = "é" * 10 + "x" * 3000
    passed = passed_text(text)
    assert_equal Embedder::MAX_CHARS, passed.length
    assert_equal text[0, 2000], passed
  end

  test "text of 2000 characters or less is passed unchanged" do
    [ "a" * 2000, "a" * 1999, "short text" ].each do |text|
      assert_equal text, passed_text(text)
    end
  end

  test "non string text is turned into a string" do
    assert_equal "12345", passed_text(12345)
  end

  test "the model is loaded once" do
    calls = []
    with_informers(fake_pipeline(calls)) do |loads|
      with_pipeline(nil) do
        Embedder.call("first")
        Embedder.call("second")
      end
      assert_equal [ [ "embedding", Embedder::MODEL ] ], loads
      assert_equal 2, calls.size
    end
  end

  test "an already loaded pipeline never calls Informers" do
    with_informers(nil) do |loads|
      with_pipeline(fake_pipeline([])) { Embedder.call("text") }
      assert_empty loads
    end
  end
end
