# == Schema Information
#
# Table name: standard_skill_entries
#
#  id                        :integer          not null, primary key
#  number                    :integer
#  letter                    :string
#  points                    :decimal(6, 2)
#  description               :string
#  created_at                :datetime
#  updated_at                :datetime
#  friendly_description      :text
#  additional_description_id :integer
#  skill_speed               :string
#  skill_before_id           :integer
#  skill_after_id            :integer
#
# Indexes
#
#  index_standard_skill_entries_on_letter_and_number  (letter,number) UNIQUE
#

class StandardSkillEntry < ApplicationRecord
  has_many :standard_skill_routine_entries, dependent: :destroy
  belongs_to :skill_before, class_name: "StandardSkillEntryTransition", optional: true
  belongs_to :skill_after, class_name: "StandardSkillEntryTransition", optional: true
  belongs_to :additional_description, class_name: "StandardSkillEntryAdditionalDescription", optional: true

  validates :number, :points, :description, presence: true
  validates :letter, presence: true, uniqueness: { scope: :number } # not allowed to have the same number/letter pair twice

  default_scope { order('number, letter') }

  def fullDescription
    "#{skill_number_and_letter} - #{description}"
  end

  def skill_number_and_letter
    "#{number}#{letter}"
  end

  def non_riding_skill
    number >= 100
  end

  def skill_speed_class
    case skill_speed
    when "Slow" # rubocop:disable Lint/EmptyWhen
    when "Medium"
      "standard_skill_row--medium"
    when "Fast"
      "standard_skill_row--fast"
    end
  end

  def self.non_riding_skills
    where("standard_skill_entries.number >= 100")
  end

  def to_s
    fullDescription
  end
end
