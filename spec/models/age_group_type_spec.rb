# == Schema Information
#
# Table name: age_group_types
#
#  id          :integer          not null, primary key
#  name        :string
#  description :string
#  created_at  :datetime
#  updated_at  :datetime
#
# Indexes
#
#  index_age_group_types_on_name  (name) UNIQUE
#

require 'spec_helper'

describe AgeGroupType do
  it "must have a name" do
    agt = described_class.new
    expect(agt.valid?).to eq(false)
    agt.name = "Default"
    expect(agt.valid?).to eq(true)
  end

  describe "with a set of age group entries" do
    before do
      @agt = FactoryBot.create(:age_group_type)
      @age1 = FactoryBot.create(:age_group_entry, age_group_type: @agt, start_age: 0, end_age: 10, gender: "Male")
      @age2 = FactoryBot.create(:age_group_entry, age_group_type: @agt, start_age: 11, end_age: 100, gender: "Male")
    end

    it "returns nil if no applicable age group entry is found" do
      expect(@agt.age_group_entry_for(-1, "Male")).to be_nil
    end

    it "returns mixed_gender_age_groups?" do
      expect(@agt).not_to be_mixed_gender_age_groups
    end

    it "can return the correct age_group_entry for a given age" do
      expect(@agt.age_group_entry_for(10, "Male")).to eq(@age1)
    end

    it "returns nil when given a female" do
      expect(@agt.age_group_entry_for(10, "Female")).to be_nil
    end

    it "returns the age group entry if it is configured with 'mixed'" do
      @age1.gender = "Mixed"
      @age1.save!
      expect(@agt.age_group_entry_for(10, "Female")).to eq(@age1)
    end

    describe "when searching a no-wheel-size age_group while using a wheel size" do
      before do
        @ws = FactoryBot.create(:wheel_size_20)
      end

      it "still finds the age group entry" do
        expect(@agt.age_group_entry_for(10, "Male", @ws.id)).to eq(@age1)
      end
    end

    describe "When the age_group_entry has a wheel size" do
      before do
        @ws20 = FactoryBot.create(:wheel_size_20)
        @ws24 = FactoryBot.create(:wheel_size_24)
        @age1.wheel_size = @ws20
        @age1.save
        @age1b = FactoryBot.create(:age_group_entry, age_group_type: @agt, start_age: 0, end_age: 12, gender: "Male", wheel_size: @ws24)
      end

      it "puts the rider on a 20\" wheel in the correct age group" do
        expect(@agt.age_group_entry_for(10, "Male", @ws20)).to eq(@age1)
      end

      it "puts the rider on a 24\" wheel in the correct age group" do
        expect(@agt.age_group_entry_for(10, "Male", @ws24)).to eq(@age1b)
      end
    end
  end

  describe "with a mixed-age-group entry" do
    before do
      @agt = FactoryBot.create(:age_group_type)
      # This is an unexpected combination of Male and Mixed, used for testing
      # to ensure that "Mixed" wins.
      @age1 = FactoryBot.create(:age_group_entry, age_group_type: @agt, start_age: 0, end_age: 10, gender: "Male")
      @age2 = FactoryBot.create(:age_group_entry, age_group_type: @agt, start_age: 11, end_age: 100, gender: "Mixed")
    end

    it "returns mixed_gender_age_groups?" do
      expect(@agt.reload).to be_mixed_gender_age_groups
    end
  end

  it "must have a unique name" do
    agt = FactoryBot.create(:age_group_type)
    agt2 = FactoryBot.build(:age_group_type, name: agt.name)
    expect(agt2.valid?).to eq(false)
  end
end
