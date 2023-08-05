# == Schema Information
#
# Table name: registrant_best_times
#
#  id              :integer          not null, primary key
#  event_id        :integer          not null
#  registrant_id   :integer          not null
#  source_location :string           not null
#  value           :integer          not null
#  created_at      :datetime
#  updated_at      :datetime
#
# Indexes
#
#  index_registrant_best_times_on_event_id_and_registrant_id  (event_id,registrant_id) UNIQUE
#  index_registrant_best_times_on_registrant_id               (registrant_id)
#

class RegistrantBestTime < ApplicationRecord
  validates :event, presence: true
  validates :event_id, uniqueness: { scope: [:registrant_id] }
  validates :registrant, :source_location, :value, presence: true
  validate :formatted_value_is_formatted

  has_paper_trail meta: { registrant_id: :registrant_id }

  belongs_to :event
  belongs_to :registrant, inverse_of: :registrant_best_times, touch: true

  before_validation :convert_value_to_integer

  delegate :hint, to: :formatter

  def formatted_value=(new_value)
    @entered_value = new_value
  end

  def formatted_value
    entered_value || formatter.to_string(value)
  end

  def to_s
    return if formatter.nil?

    "Best Time: #{formatted_value} @ #{source_location}"
  end

  private

  attr_accessor :entered_value

  def convert_value_to_integer
    self.value = formatter.from_string(entered_value) if entered_value && formatter.valid?(entered_value)
  end

  def formatter
    case event.best_time_format
    when Event::BEST_TIME_FORMAT_HOUR_MINUTE
      BestTimeFormatter::HourMinuteFormatter
    when Event::BEST_TIME_FORMAT_HOUR_MINUTE_SECOND
      BestTimeFormatter::MinuteSecondFormatter
    when Event::BEST_TIME_FORMAT_CENTIMETER
      BestTimeFormatter::CentimeterFormatter
    end
  end

  def formatted_value_is_formatted
    return unless entered_value

    unless formatter.valid?(entered_value)
      errors.add(:formatted_value, "Value must match format #{formatter.hint}. #{formatter.error_message}")
    end
  end
end
