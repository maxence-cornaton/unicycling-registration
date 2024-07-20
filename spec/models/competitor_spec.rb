# == Schema Information
#
# Table name: competitors
#
#  id                       :integer          not null, primary key
#  competition_id           :integer
#  position                 :integer
#  custom_name              :string
#  created_at               :datetime
#  updated_at               :datetime
#  status                   :integer          default("active")
#  lowest_member_bib_number :integer
#  geared                   :boolean          default(FALSE), not null
#  riding_wheel_size        :integer
#  notes                    :string
#  wave                     :integer
#  riding_crank_size        :integer
#  withdrawn_at             :datetime
#  tier_number              :integer          default(1), not null
#  tier_description         :string
#  age_group_entry_id       :integer
#
# Indexes
#
#  index_competitors_event_category_id                         (competition_id)
#  index_competitors_on_competition_id_and_age_group_entry_id  (competition_id,age_group_entry_id)
#

require 'spec_helper'

describe Competitor do
  let(:competition) { FactoryBot.build_stubbed(:timed_competition) }

  before do
    @comp = FactoryBot.build_stubbed(:event_competitor, competition: competition)
    allow(@comp).to receive(:lower_is_better).and_return(true)
    Rails.cache.clear
  end

  it "has a time_result in thousands when no results" do
    expect(@comp.best_time_in_thousands).to eq(0)
  end

  describe "when there are time results" do
    before do
      @tr1 = FactoryBot.build_stubbed(:time_result, minutes: 1)
      allow(@comp).to receive(:finish_time_results).and_return([@tr1])
    end

    it "has a best_time_in_thousands" do
      expect(@comp.best_time_in_thousands).to eq(60000)
    end

    describe "when there is also a start time" do
      before do
        @tr2 = FactoryBot.build_stubbed(:time_result, is_start_time: true, seconds: 10)
        allow(@comp).to receive(:start_time_results).and_return([@tr2])
      end

      it "has the correct best_time_in_thousands" do
        expect(@comp.best_time_in_thousands).to eq(50000)
      end
    end

    describe "when there is a matching wave + wave_time" do
      before do
        allow(competition).to receive(:wave_time_for).with(1).and_return(30)
      end

      it "uses the wave time for start times" do
        @comp.wave = 1
        expect(@comp.best_time_in_thousands).to eq(30000)
      end
    end
  end

  describe "when there are multiple start and end times" do
    before do
      @start1 = FactoryBot.build_stubbed(:time_result, is_start_time: true, minutes: 1)
      @start2 = FactoryBot.build_stubbed(:time_result, is_start_time: true, minutes: 10)

      @end1 = FactoryBot.build_stubbed(:time_result, minutes: 2, seconds: 30)
      @end2 = FactoryBot.build_stubbed(:time_result, minutes: 10, seconds: 45)

      allow(@comp).to receive(:start_time_results).and_return([@start1, @start2])
      allow(@comp).to receive(:finish_time_results).and_return([@end1, @end2])
    end

    describe "with lower_is_better" do
      before do
        Rails.cache.clear
        allow(@comp).to receive(:lower_is_better).and_return(true)
      end

      it "has the correct best_time_in_thousands" do
        expect(@comp.best_time_in_thousands).to eq(45000)
      end
    end

    describe "with higher_is_better" do
      before do
        Rails.cache.clear
        allow(competition).to receive(:scoring_class).and_return "Longest Time"
      end

      it "has the correct best_time_in_thousands" do
        expect(@comp.best_time_in_thousands).to eq(90000)
      end
    end
  end

  describe "when there are end times without start times" do
    before do
      @end1 = FactoryBot.build_stubbed(:time_result, minutes: 2, seconds: 30)
      @end2 = FactoryBot.build_stubbed(:time_result, minutes: 10, seconds: 45)

      allow(@comp).to receive(:finish_time_results).and_return([@end1, @end2])
    end

    it "has the correct best_time_in_thousands" do
      expect(@comp.best_time_in_thousands).to eq(150000)
    end
  end

  describe "with a contact_detail with club, state, country" do
    let(:contact_detail) { FactoryBot.build(:contact_detail, state_code: "IL", country_representing: "US", club: "My Club") }
    let(:registrant) { FactoryBot.build(:competitor, contact_detail: contact_detail) }
    before do
      allow(@comp).to receive(:members).and_return([registrant])
    end

    let(:subject) { @comp }

    include_context 'can display correct state, country, club', state: "Illinois", country: "United States", club: "My Club"
  end
end

describe Competitor do
  let(:competition) { FactoryBot.create(:competition) }

  before do
    @comp = FactoryBot.create(:event_competitor, competition: competition)
  end

  it "joins a registrant and a event" do
    reg = FactoryBot.create(:registrant)

    competition = FactoryBot.create(:competition)

    comp = described_class.new
    comp.registrants << reg
    comp.competition = competition
    comp.position = 1
    expect(comp.save).to eq(true)
  end

  it "modifies the other competitor's position" do
    competition = FactoryBot.create(:competition)
    reg1 = FactoryBot.create(:registrant)
    reg2 = FactoryBot.create(:registrant)

    comp = described_class.new
    comp.registrants << reg1
    comp.competition = competition
    comp.position = 1
    expect(comp.save).to eq(true)

    comp = described_class.new
    comp.registrants << reg2
    comp.competition = competition
    comp.position = 1
    expect(comp.save).to eq(true)

    comps = competition.competitors
    expect(comps.count).to eq(2)
    expect(comps[0].position).to eq(1)
    expect(comps[1].position).to eq(2)
  end

  it "has name/id from the registrant" do
    reg = @comp.registrants.first

    expect(@comp.name).to eq(reg.name)
    expect(@comp.bib_number).to eq(reg.external_id.to_s)
  end

  it "is elgiible" do
    expect(@comp.ineligible?).to eq(false)
  end

  describe "when event configuration defines the start date of convention" do
    before do
      EventConfiguration.singleton.update(start_date: Date.current)
    end

    it "has updated age when a members age is updated" do
      registrant = @comp.members.first.registrant
      expect(@comp.age).to eq(registrant.age)

      # to burst the cache on Competitor#age
      travel 2.seconds do
        expect do
          registrant.birthday -= 2.years
          registrant.save
        end.to change { registrant.reload.age }
      end

      expect(@comp.reload.age).to eq(registrant.age)
    end
  end

  it "does not set the external name if it is a blank-string" do
    @comp.custom_name = ""
    reg = @comp.registrants.first

    expect(@comp.bib_number).to eq(reg.external_id.to_s)
    expect(@comp.name).to eq(reg.name)
  end

  it "allows setting the custom_name to nil" do
    @comp.custom_name = nil
    expect(@comp.valid?).to eq(true)
  end

  it "must have 3 competitors to allow a custom name" do
    @comp.custom_name = "Sargent Pepper"
    expect(@comp.valid?).to eq(false)
    member2 = @comp.members.build
    member3 = @comp.members.build
    member2.registrant = FactoryBot.create(:registrant)
    member3.registrant = FactoryBot.create(:registrant)
    expect(@comp.valid?).to eq(true)
    expect(@comp.valid?).to eq(true)
    expect(@comp.name).to eq("Sargent Pepper")
  end

  it "setting the same position for another competitor should modify the original competitor" do
    c2 = FactoryBot.build(:event_competitor, competition: @comp.competition, position: @comp.position)

    expect(c2.valid?).to eq(true)
    expect(c2.save).to eq(true)

    comp_again = described_class.find(@comp.id)
    expect(comp_again.position).not_to eq(c2.position)
  end

  describe "when checking the export_id field" do
    it "returns the registrant when only one" do
      expect(@comp.export_id).to eq(@comp.registrants.first.external_id)
    end

    it "returns the first registrant when two registrants" do
      @comp.registrants << FactoryBot.create(:registrant)
      @comp.save!
      expect(@comp.registrants.map(&:external_id)).to include(@comp.export_id)
    end
  end

  it "deletes the competitor if the last member is deleted" do
    member = @comp.reload.members.first

    expect do
      member.destroy
    end.to change(described_class, :count).by(-1)
  end

  describe "when it has multiple members" do
    before do
      EventConfiguration.singleton.update(start_date: Date.current)
      member = @comp.reload.members.first
      @reg1 = member.registrant

      travel 2.seconds do
        @comp.reload
        member2 = FactoryBot.create(:member, competitor: @comp)
        @comp.reload
        @reg2 = member2.registrant
      end
    end

    it "displays the external id's for all members" do
      expect(@comp.bib_number).to eq("#{@reg1.external_id}, #{@reg2.external_id}")
    end

    it "displays the ages for all members (when they are the same)" do
      expect(@comp.age).to eq(@reg1.age)
    end

    it "stores the mimimum bib_number" do
      lowest = [@reg1.bib_number, @reg2.bib_number].min
      expect(@comp.lowest_member_bib_number).to be(lowest)
    end

    it "displays the maximum ages for all members (when they are different)" do
      travel 2.seconds do
        @reg3 = FactoryBot.create(:registrant, birthday: 20.years.ago)
        @comp2 = FactoryBot.create(:event_competitor)
        FactoryBot.create(:member, competitor: @comp2, registrant: @reg3)
        @comp2.reload
      end

      expect(@comp2.age).to eq(@reg3.age)
    end

    it "displays '(mixed)', if there are multiple members (even if they are the same gender)" do
      # this is so that the overall placing calculation works properly with mixed-gender groups
      expect(@comp.gender).to eq("(mixed)")
    end

    it "can determine the majority country" do
      expect(@comp.majority_country(["USA"])).to eq("USA")
      expect(@comp.majority_country(["USA", nil])).to eq("USA")
      expect(@comp.majority_country(["USA", "Canada"])).to eq("Canada, USA")
      expect(@comp.majority_country(["USA", "Canada", "Canada"])).to eq("Canada")
      expect(@comp.majority_country([nil, nil])).to eq(nil)
    end

    it "displays the source country" do
      expect(@comp.country).to eq(@reg1.country)
    end

    it "displays (mixed) if both genders exist" do
      travel 2.seconds do
        @reg3 = FactoryBot.create(:registrant, gender: "Female")
        FactoryBot.create(:member, competitor: @comp, registrant: @reg3)
        @comp.reload
      end

      expect(@comp.gender).to eq("(mixed)")
    end

    it "responds to member_has_bib_number?" do
      expect(@comp.member_has_bib_number?(@reg1.bib_number)).to eq(true)
      expect(@comp.member_has_bib_number?(@reg2.bib_number)).to eq(true)
      expect(@comp.member_has_bib_number?(-1)).to eq(false)
    end

    context "when a member is deleted" do
      it "noes longer show the deleted competitor's name", :caching do
        member1 = @comp.members.first
        member2 = @comp.members.second
        expect(@comp.registrants_names).to include(member1.to_s)
        expect(@comp.registrants_names).to include(member2.to_s)
        member2.destroy # must destroy the not-lowest-number competitor
        expect(@comp.reload.registrants_names).to eq(member1.to_s)
      end
    end
  end

  describe "when a join pair exists" do
    before do
      @reg = FactoryBot.create(:registrant)

      @competition = FactoryBot.create(:competition)

      @competition.create_competitors_from_registrants([@reg])
      @cr = @competition.competitors.first

      @score = Score.new
      @score.val_1 = 1.0
      @score.val_2 = 2.0
      @score.val_3 = 3.0
      @score.val_4 = 4.0
      @score.judge = FactoryBot.create(:judge,
                                       user: FactoryBot.create(:user),
                                       judge_type: FactoryBot.create(:judge_type))
      @score.competitor = @cr
      @score.save
      @competition.reload
      @reg.reload
    end

    it "is able to access the reg via event" do
      expect(@competition.registrants).to eq([@reg])
    end

    it "is able to access the event via reg" do
      expect(@reg.competitions).to eq([@competition])
    end

    it "is able to access the competitors via competition" do
      expect(@competition.competitors).to eq([@cr])
    end

    it "is able to access the competitors via registrant" do
      expect(@reg.competitors).to eq([@cr])
    end

    it "is able to access the scores via competitor" do
      expect(@cr.scores).to eq([@score])
    end
  end

  describe "with a standard skill score" do
    before do
      @st_score = FactoryBot.create(:standard_skill_score)
    end

    it "is able to get the scores from the competitor" do
      expect(@st_score.competitor.standard_skill_scores).to eq([@st_score])
    end
  end

  describe "with a score" do
    before do
      @score = FactoryBot.create(:score)
    end

    it "deletes the score when the associated competitor is deleted" do
      @comp = @score.competitor
      expect(Score.count).to eq(1)
      @comp.destroy
      expect(Score.count).to eq(0)
    end
  end

  describe "with a boundary_score" do
    before do
      @score = FactoryBot.create(:boundary_score)
    end

    it "deletes the boundary_score when the associated competitor is deleted" do
      @comp = @score.competitor
      expect(BoundaryScore.count).to eq(1)
      @comp.destroy
      expect(BoundaryScore.count).to eq(0)
    end
  end

  describe "with a distance attempt" do
    let(:competition) { FactoryBot.create(:distance_competition) }

    before do
      travel 2.seconds do
        @da = DistanceAttempt.new
      end
    end

    it "is accessible from the competitor" do
      da = FactoryBot.create(:distance_attempt, competitor: @comp)

      expect(@comp.distance_attempts).to eq([da])
    end

    it "deletes related distance_attempts if the competitor is deleted" do
      comp = FactoryBot.create(:event_competitor, competition: competition)
      FactoryBot.create(:distance_attempt, competitor: comp)

      expect(DistanceAttempt.count).to eq(1)
      travel 2.seconds do
        comp.destroy
      end
      expect(DistanceAttempt.count).to eq(0)
    end

    it "indicates no_more_jumps if two attempts at the same distance are found" do
      expect(@comp.no_more_jumps?).to eq(false)
      FactoryBot.create(:distance_attempt, competitor: @comp, fault: true)
      expect(@comp.reload.no_more_jumps?).to eq(false)

      travel 2.seconds do
        FactoryBot.create(:distance_attempt, competitor: @comp, fault: true)
      end

      expect(@comp.reload.no_more_jumps?).to eq(true)
    end

    it "does not indicate no_more_jumps if two consecutive attempts at different distances are found" do
      expect(@comp.no_more_jumps?).to eq(false)
      da1 = FactoryBot.create(:distance_attempt, competitor: @comp, fault: true)
      expect(@comp.reload.no_more_jumps?).to eq(false)
      travel 2.seconds do
        FactoryBot.create(:distance_attempt, distance: da1.distance + 1, competitor: @comp, fault: true)
      end

      expect(@comp.reload.no_more_jumps?).to eq(false)
    end

    it "returns the max attempted distance" do
      expect(@comp.max_attempted_distance).to eq(0)
      expect(@comp.max_successful_distance).to be_nil
      da1 = FactoryBot.create(:distance_attempt, competitor: @comp, fault: true)
      expect(@comp.reload.max_attempted_distance).to eq(da1.distance)
      expect(@comp.reload.max_successful_distance).to be_nil
    end

    it "returns the attempts is descending distance order" do
      da1 = FactoryBot.create(:distance_attempt, distance: 1, competitor: @comp, fault: false)
      da2 = FactoryBot.create(:distance_attempt, distance: 2, competitor: @comp, fault: false)
      da3 = FactoryBot.create(:distance_attempt, distance: 3, competitor: @comp, fault: false)

      expect(@comp.reload.distance_attempts).to eq([da3, da2, da1])
    end

    it "returns the attempts in descending attempt order (if the same distance)" do
      da1 = FactoryBot.create(:distance_attempt, distance: 1, competitor: @comp, fault: true)
      da2 = FactoryBot.create(:distance_attempt, distance: 1, competitor: @comp, fault: false)

      expect(@comp.reload.distance_attempts).to eq([da2, da1])
    end

    it "describes the status clearly" do
      expect(@comp.distance_attempt_status).to eq("Not Attempted")
    end

    describe "when attempts have already been made" do
      before do
        FactoryBot.create(:distance_attempt, competitor: @comp, distance: 10, fault: false)
        travel 2.seconds do
          FactoryBot.create(:distance_attempt, competitor: @comp, distance: 15, fault: true)
        end
      end

      before do
        travel 4.seconds
      end

      after do
        travel_back
      end

      it "is not allowed to attempt a smaller distance" do
        da = FactoryBot.build(:distance_attempt, competitor: @comp, distance: 5)

        expect(da.valid?).to eq(false)
      end

      it "returns the max successful distance" do
        expect(@comp.max_successful_distance).to eq(10)
      end

      it "does not allow another attempt when in double-fault" do
        FactoryBot.create(:distance_attempt, competitor: @comp, distance: 15, fault: true)
        da = FactoryBot.build(:distance_attempt, competitor: @comp, distance: 25, fault: false)

        expect(@comp.reload.no_more_jumps?).to eq(true)
        expect(da.valid?).to eq(false)
      end

      describe "when there are 2 faults" do
        before do
          @da2 = FactoryBot.create(:distance_attempt, competitor: @comp, distance: 15, fault: true)
        end

        it "allows the 2nd attempt to also be a fault" do
          expect(@comp.reload.no_more_jumps?).to eq(true)
          expect(@da2.valid?).to eq(true)
        end

        it "describes the status" do
          expect(@comp.reload.distance_attempt_status).to eq("Finished. Final Score 10cm")
        end
      end

      it "allows multiple faults, interspersed within the attempts" do
        FactoryBot.create(:distance_attempt, competitor: @comp, distance: 20, fault: false)
        # Created 2 seconds in the future:
        FactoryBot.create(:distance_attempt, competitor: @comp, distance: 25, fault: true, created_at: 2.seconds.from_now)

        da = FactoryBot.build(:distance_attempt, competitor: @comp, distance: 25, fault: false)

        expect(da.valid?).to eq(true)
      end

      it "describes its status clearly" do
        expect(@comp.reload.distance_attempt_status).to eq("Fault. Next Distance 15cm+")
      end

      describe "the last attempt was a success" do
        before do
          FactoryBot.create(:distance_attempt, competitor: @comp, distance: 20, fault: false)
        end

        it "has a nice status" do
          expect(@comp.reload.distance_attempt_status).to eq("Success. Next Distance 21cm +")
        end
      end
    end
  end

  describe "has_music?" do
    context "without a song" do
      it { expect(@comp).not_to have_music }
    end

    context "with music" do
      let!(:song) { FactoryBot.create(:song, competitor: @comp) }

      it { expect(@comp).to have_music }
    end
  end

  describe "when it has multiple time results" do
    describe "when there are DQs and live results" do
      before do
        @comp.competition.scoring_class = "Shortest Time"
        @end1 = FactoryBot.create(:time_result, competitor: @comp, minutes: 2, seconds: 30)
        @end2 = FactoryBot.create(:time_result, competitor: @comp, minutes: 0, seconds: 45, status: "DQ")
      end

      it "doesn't choose DQ as the best time" do
        expect(@comp.best_time_in_thousands).to eq(150000)
      end
    end
  end

  describe "with an ineligible registrant" do
    before do
      @reg = @comp.reload.registrants.first
      @reg.ineligible = true
      @reg.save!
    end

    it "is ineligible itself" do
      expect(@comp).to be_ineligible
    end
  end
end
