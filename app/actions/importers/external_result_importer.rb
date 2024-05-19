class Importers::ExternalResultImporter < Importers::CompetitionDataImporter
  def process(processor)
    unless processor.valid_file?
      @errors = processor.errors
      return false
    end

    # FOR EXCEL DATA:
    raw_data = processor.file_contents
    self.num_rows_processed = 0
    @errors = []
    ExternalResult.transaction do
      raw_data.each do |raw|
        if build_and_save_imported_result(processor.process_row(raw), @user, @competition)
          self.num_rows_processed += 1
        else
          raise ActiveRecord::Rollback
        end
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @errors << e.message
    false
  end

  # from CSV to import_result
  def build_and_save_imported_result(row_hash, user, competition)
    competitor_finder = FindCompetitorForCompetition.new(row_hash[:bib_number], competition)
    competitor = competitor_finder.competitor
    raise ActiveRecord::RecordNotFound if competitor.nil?

    result = ExternalResult.preliminary.create(
      competitor: competitor,
      points: row_hash[:points],
      details: row_hash[:details],
      status: row_hash[:status],
      entered_at: Time.current,
      entered_by: user
    )
    if result.persisted?
      true
    else
      result.errors.full_messages.each do |message|
        @errors << message
      end
      false
    end
  rescue ActiveRecord::RecordNotFound
    @errors << "Unable to find registrant (#{row_hash})"
    false
  end
end
