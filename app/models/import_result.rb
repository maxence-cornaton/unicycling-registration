# == Schema Information
#
# Table name: import_results
#
#  id                  :integer          not null, primary key
#  user_id             :integer
#  raw_data            :string
#  bib_number          :integer
#  minutes             :integer
#  seconds             :integer
#  thousands           :integer
#  created_at          :datetime
#  updated_at          :datetime
#  competition_id      :integer
#  points              :decimal(6, 3)
#  details             :string
#  is_start_time       :boolean          default(FALSE), not null
#  number_of_laps      :integer
#  status              :string
#  comments            :text
#  comments_by         :string
#  heat                :integer
#  lane                :integer
#  number_of_penalties :integer
#
# Indexes
#
#  index_import_results_on_user_id  (user_id)
#  index_imported_results_user_id   (user_id)
#

class ImportResult < ApplicationRecord
  include StatusNilWhenEmpty
  include FindsMatchingCompetitor
  include HoursFacade

  validates :competition, presence: true
  validates :user, :bib_number, presence: true
  validate :results_for_competition
  validates :minutes, :seconds, :thousands, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validates :status, inclusion: { in: TimeResult.status_values, allow_nil: true }
  before_validation :set_details_if_blank
  validates :details, presence: true, if: -> { points? }
  validates :is_start_time, inclusion: { in: [true, false] }

  belongs_to :user
  belongs_to :competition

  default_scope { order(:bib_number) }

  scope :entered_order, -> { reorder(:id) }

  before_validation :set_zeros

  def disqualified?
    status == "DQ" || status == "DNF"
  end

  # import the result in the results table, raise an exception on failure
  def import!
    raise "Unable to find registrant" if matching_registrant.nil?

    competitor = matching_competitor
    target_competition = competition
    if competitor.nil?
      import_into_matching_competitions = competition.import_results_into_other_competition?
      if import_into_matching_competitions
        matching_competition = matching_registrant.matching_competition_in_event(competition.event)
        if matching_competition
          # another competition with a competitor in the same event exists, use a competitor there
          competitor = matching_registrant.competitors.find_by(competition: matching_competition)
          raise "error finding matching competitor" if competitor.nil?

          target_competition = matching_competition
        end
      end
    end
    if competitor.nil? && competition.allow_competitor_creation_during_import_approval?
      # still no competitor, create one in the current event
      registrant = matching_registrant
      target_competition.create_competitor_from_registrants([registrant], nil)
      competitor = target_competition.find_competitor_with_bib_number(bib_number)
    end

    tr = target_competition.build_result_from_imported(self)
    tr.competitor = competitor
    tr.save!
  end

  def full_time
    TimeResultPresenter.new(minutes, seconds, thousands, data_entry_format: competition.data_entry_format).full_time
  end

  private

  # Set thousands to 0 if there is no way to enter anything that precise
  def set_zeros
    return if competition.nil?

    self.thousands = 0 unless competition.data_entry_format.thousands? || competition.data_entry_format.hundreds?
  end

  # determines that the import_result has enough information
  def results_for_competition
    return if disqualified?
    return if competition.nil?

    if competition.imports_times?
      unless time_is_present?
        errors.add(:base, "Must enter full time")
      end
    else
      unless points?
        errors.add(:base, "Must select either time or points")
      end
    end
  end

  def time_is_present?
    minutes && seconds && thousands
  end

  def set_details_if_blank
    if details.blank? && points?
      self.details = "#{points}pts"
    end
  end
end
