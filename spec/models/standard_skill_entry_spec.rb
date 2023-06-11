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

require 'spec_helper'

describe StandardSkillEntry do
  it "can save the necessary fields" do
    std = described_class.new
    std.number = 2
    std.letter = "a"
    std.points = 1.3
    std.description = "riding holding seatpost, one hand"
    expect(std.valid?).to eq(true)
  end

  it "displays a full description" do
    std = FactoryBot.build(:standard_skill_entry)
    expect(std.fullDescription).to eq("#{std.number}#{std.letter} - riding - 8")
  end
  it "is a non_riding_skill if >= 100" do
    std = FactoryBot.build(:standard_skill_entry)
    expect(std.non_riding_skill).to eq(false)

    std = FactoryBot.build(:standard_skill_entry, number: 100)
    expect(std.non_riding_skill).to eq(true)
  end

  describe "with associated routine entries" do
    before do
      @entry = FactoryBot.create(:standard_skill_routine_entry)
    end

    it "has associated entry" do
      skill = @entry.standard_skill_entry
      expect(skill.standard_skill_routine_entries).to eq([@entry])
    end
    it "removes the associated entry upon destroy" do
      skill = @entry.standard_skill_entry
      expect do
        skill.destroy
      end.to change(StandardSkillRoutineEntry, :count).by(-1)
    end
  end
end
