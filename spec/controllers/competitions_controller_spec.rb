# == Schema Information
#
# Table name: competitions
#
#  id                                    :integer          not null, primary key
#  event_id                              :integer
#  name                                  :string
#  created_at                            :datetime
#  updated_at                            :datetime
#  age_group_type_id                     :integer
#  has_experts                           :boolean          default(FALSE), not null
#  scoring_class                         :string
#  start_data_type                       :string
#  end_data_type                         :string
#  uses_lane_assignments                 :boolean          default(FALSE), not null
#  scheduled_completion_at               :datetime
#  awarded                               :boolean          default(FALSE), not null
#  award_title_name                      :string
#  award_subtitle_name                   :string
#  num_members_per_competitor            :string
#  automatic_competitor_creation         :boolean          default(FALSE), not null
#  combined_competition_id               :integer
#  order_finalized                       :boolean          default(FALSE), not null
#  penalty_seconds                       :integer
#  locked_at                             :datetime
#  published_at                          :datetime
#  sign_in_list_enabled                  :boolean          default(FALSE), not null
#  time_entry_columns                    :string           default("minutes_seconds_thousands")
#  import_results_into_other_competition :boolean          default(FALSE), not null
#  base_age_group_type_id                :integer
#  score_ineligible_competitors          :boolean          default(FALSE), not null
#  results_header                        :string
#  hide_max_laps_count                   :boolean          default(FALSE), not null
#
# Indexes
#
#  index_competitions_event_id                    (event_id)
#  index_competitions_on_base_age_group_type_id   (base_age_group_type_id)
#  index_competitions_on_combined_competition_id  (combined_competition_id) UNIQUE
#

require 'spec_helper'

describe CompetitionsController do
  before do
    @admin_user = FactoryBot.create(:super_admin_user)
    sign_in @admin_user
    @event = FactoryBot.create(:event)
    @event_category = @event.event_categories.first
  end

  let(:competition) { FactoryBot.create(:competition, event: @event) }

  describe "#show" do
    it "renders successfully" do
      get :show, params: { id: competition.id }
      expect(response).to be_successful
    end
  end

  describe "#toggle_final_sort" do
    it "changes the final_sort status" do
      put :toggle_final_sort, params: { id: competition.id }
      expect(competition.reload).to be_order_finalized

      # and back again
      put :toggle_final_sort, params: { id: competition.id }
      expect(competition.reload).not_to be_order_finalized
    end
  end

  describe "#set_sort" do
    it "renders" do
      get :set_sort, params: { id: competition.id }
      expect(response).to be_successful
    end
  end

  describe "#sort_random" do
    it "redirects to sort path" do
      post :sort_random, params: { id: competition.id }
      expect(response).to redirect_to(set_sort_competition_path(competition))
    end
  end

  describe "#set_age_group_places" do
    let(:competition) { FactoryBot.create(:timed_competition) }
    let(:age_group_type) { competition.age_group_type }
    let!(:age_group_entry) { FactoryBot.create(:age_group_entry, age_group_type: age_group_type) }

    context "with valid params" do
      it "renders" do
        post :set_age_group_places, params: { id: competition.id, age_group_entry_id: age_group_entry.id }
        expect(response).to redirect_to(competition_path(competition))
      end
    end

    context "with invalid params" do
      it "renders" do
        post :set_age_group_places, params: { id: competition.id }
        expect(response).to redirect_to(competition_path(competition))
      end
    end
  end

  describe "#set_places" do
    it "renders" do
      post :set_places, params: { id: competition.id }
      expect(response).to redirect_to(result_competition_path(competition))
    end
  end

  describe "#result" do
    it "renders" do
      get :result, params: { id: competition.id }
      expect(response).to be_successful
    end
  end

  describe "POST lock" do
    it "locks the competition" do
      competition = FactoryBot.create(:competition, event: @event)
      post :lock, params: { id: competition.to_param }
      competition.reload
      expect(competition.locked?).to eq(true)
    end
  end

  describe "DELETE lock" do
    it "unlocks the competition" do
      competition = FactoryBot.create(:competition, :locked, event: @event)
      delete :unlock, params: { id: competition.to_param }
      competition.reload
      expect(competition.locked?).to eq(false)
    end
  end

  describe "POST publish_age_group_entry" do
    let(:competition) { FactoryBot.create(:timed_competition, :locked) }
    let(:age_group_type) { competition.age_group_type }
    let!(:age_group_entry) { FactoryBot.create(:age_group_entry, age_group_type: age_group_type) }

    context "with valid params" do
      it "publishes the age group entry" do
        post :publish_age_group_entry, params: { id: competition.id, age_group_entry: age_group_entry.id }
        expect(response).to redirect_to(competition_path(competition))
      end
    end

    context "with invalid params" do
      it "renders" do
        post :publish_age_group_entry, params: { id: competition.id }
        expect(response).to redirect_to(competition_path(competition))
      end
    end
  end

  describe "POST publish" do
    it "publishes the competition results" do
      competition = FactoryBot.create(:competition, :locked, event: @event)
      post :publish, params: { id: competition.to_param }
      competition.reload
      expect(competition.published?).to eq(true)
    end
  end

  describe "DELETE publish" do
    it "un-publishes the competition" do
      competition = FactoryBot.create(:competition, :locked, :published, event: @event)
      delete :unpublish, params: { id: competition.to_param }
      competition.reload
      expect(competition.published?).to eq(false)
    end
  end

  describe "POST create_last_minute_competitor" do
    let(:new_registrant) { FactoryBot.create(:competitor) }
    let!(:config) { FactoryBot.create(:event_configuration, :with_usa) }

    it "creates a competitor for the competition" do
      expect do
        post :create_last_minute_competitor, params: { id: competition.id, registrant_id: new_registrant.id, registrant_type: "Registrant", format: :js }
      end.to change(Competitor, :count).by(1)
    end

    context "with a withdrawn competitor for this registrant" do
      before do
        @withdrawn_competitor = FactoryBot.create(:event_competitor, competition: competition, status: "withdrawn")
        @withdrawn_competitor.members.first.update_attribute(:registrant_id, new_registrant.id)
      end

      it "changes the competitor status" do
        expect do
          post :create_last_minute_competitor, params: { id: competition.id, registrant_id: new_registrant.id, registrant_type: "Registrant", format: :js }
        end.to change { @withdrawn_competitor.reload.status }.to("active")
      end
    end
  end

  context "with a competitor and judge" do
    let!(:competitor) { FactoryBot.create(:event_competitor, competition: competition) }
    let!(:judge) { FactoryBot.create(:judge, competition: competition) }

    it "can refresh" do
      put :refresh_competitors, params: { id: competition.id }
      expect(response).to redirect_to(competition)
    end
  end
end
