class Embedder
  MODEL = "sentence-transformers/all-MiniLM-L6-v2".freeze
  MAX_CHARS = 2000

  # Returns one flat Array of 384 Floats (mean pooled, L2-normalized).
  def self.call(text)
    raise ArgumentError, "text is blank" if text.to_s.strip.empty?

    pipeline.(text.to_s[0, MAX_CHARS], pooling: "mean", normalize: true)
  end

  # Loaded once per process; the first call downloads the ~90 MB model.
  def self.pipeline
    @pipeline ||= Informers.pipeline("embedding", MODEL)
  end
  private_class_method :pipeline
end
