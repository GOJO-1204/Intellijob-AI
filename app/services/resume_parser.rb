require "pdf/reader"
require "docx"

class ResumeParser
  class Error < StandardError; end
  MAX_PAGES = 5
  MAX_DOCX_XML = 1.megabyte
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
    result = clean(text)
    if result.blank?
      raise Error, "We could not find any text in that file. Please upload a PDF or DOCX that is not a scan or an image."
    end
    result
  rescue Error
    raise
  rescue StandardError
    raise Error, "We couldn't read that file. It may be corrupt."
  end

  def self.read_pdf(data)
    reader = PDF::Reader.new(StringIO.new(data))
    raise Error, "Please upload a resume of #{MAX_PAGES} pages or fewer." if reader.page_count > MAX_PAGES

    reader.pages.map(&:text).join("\n")
  end

  def self.read_docx(data)
    check_docx_size(data)
    Docx::Document.open(StringIO.new(data)).paragraphs.map(&:text).join("\n")
  end

  def self.check_docx_size(data)
    Zip::File.open_buffer(StringIO.new(data)) do |zip|
      entry = zip.find_entry("word/document.xml")
      next if entry.nil?

      xml = entry.get_input_stream.read(MAX_DOCX_XML + 1)
      raise Error, "That file has too much content. Please upload a normal resume." if xml.to_s.bytesize > MAX_DOCX_XML
    end
  end

  def self.clean(text)
    text.to_s.gsub(/\r\n?/, "\n").gsub(/[^\S\n]+/, " ")
        .lines.map(&:strip).join("\n").gsub(/\n{3,}/, "\n\n").strip
  end

  private_class_method :read_pdf, :read_docx, :check_docx_size, :clean
end
