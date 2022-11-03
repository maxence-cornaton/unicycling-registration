# == Schema Information
#
# Table name: lane_assignments
#
#  id             :integer          not null, primary key
#  competition_id :integer
#  heat           :integer
#  lane           :integer
#  created_at     :datetime
#  updated_at     :datetime
#  competitor_id  :integer
#
# Indexes
#
#  index_lane_assignments_on_competition_id                    (competition_id)
#  index_lane_assignments_on_competition_id_and_heat_and_lane  (competition_id,heat,lane) UNIQUE
#

class LaneAssignment < ApplicationRecord
  belongs_to :competition
  belongs_to :competitor, touch: true, optional: true
  include CompetitorAutoCreation

  validates :competition, :competitor, :heat, :lane, presence: true
  validates :heat, uniqueness: { scope: %i[competition_id lane] }

  default_scope { order(:heat, :lane) }

  attr_accessor :allow_competitor_auto_creation # for use in causing CompetitorAutoCreation in expert heats

  def status
    matching_record.try(:status)
  end

  def comments
    matching_record.try(:comments)
  end

  def matching_record
    @matching_record ||= HeatLaneJudgeNote.find_by(competition: competition, heat: heat, lane: lane)
  end
end
