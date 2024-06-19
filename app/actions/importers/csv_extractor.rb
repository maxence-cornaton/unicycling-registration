require 'csv'

class Importers::CsvExtractor
  attr_reader :file, :separator

  class ParseError < StandardError
  end

  def initialize(file, separator: ',')
    @file = file
    @separator = separator
  end

  def extract_csv
    if file.respond_to?(:tempfile)
      upload_file = file.tempfile
    elsif file.respond_to?(:file)
      upload_file = file.file
    else
      upload_file = file
    end

    begin
      return clean_result(attempt_parse(upload_file, "UTF-8"))
    rescue ParseError, CSV::MalformedCSVError
      # If it fails to parse the file as UTF-8, try again
      begin
        return clean_result(attempt_parse(upload_file, "ISO-8859-1"))
      rescue ParseError # rubocop:disable Lint/SuppressedException
      end
    end

    raise CSV::MalformedCSVError.new("Unable to parse line")
  end

  private

  def attempt_parse(upload_file, encoding)
    if upload_file.is_a?(Aws::S3::Object)
      CSV.parse(upload_file.get.body.string, encoding: encoding, col_sep: separator)
    else
      CSV.read(upload_file, encoding: encoding, col_sep: separator)
    end
  rescue ArgumentError
    raise ParseError
  end

  # If there's an extra newline, ignore it
  def clean_result(result)
    result.each.select(&:present?)
  end
end
