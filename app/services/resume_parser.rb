require "pdf/reader"
require "docx"

class ResumeParser
  class Error < StandardError; end
  PDF_TYPE  = "application/pdf".freeze
  DOCX_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document".freeze

  def self.call(attachment)
    raise Error, "Please upload your resume." unless attachment&.attached?
    data = attachment.download
    text =
      case attachment.blob.content_type
      when PDF_TYPE  then read_pdf(data)
      when DOCX_TYPE then read_docx(data)
      else raise Error, "Please upload a PDF or DOCX file."
      end
    clean(text)
  rescue Error
    raise
  rescue StandardError
    raise Error, "We couldn't read that file. It may be corrupt."
  end

  def self.read_pdf(data)
    PDF::Reader.new(StringIO.new(data)).pages.map(&:text).join("\n")
  end

  def self.read_docx(data)
    Docx::Document.open(StringIO.new(data)).paragraphs.map(&:text).join("\n")
  end

  def self.clean(text)
    text.to_s.gsub(/\r\n?/, "\n").gsub(/[^\S\n]+/, " ")
        .lines.map(&:strip).join("\n").gsub(/\n{3,}/, "\n\n").strip
  end

  private_class_method :read_pdf, :read_docx, :clean
end
