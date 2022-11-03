require 'spec_helper'

describe HeatExportsController do
  let(:competition) { FactoryBot.create(:timed_competition) }

  before do
    @user = FactoryBot.create(:super_admin_user)
    sign_in @user
  end

  describe "GET index" do
    it "can view" do
      get :index, params: { competition_id: competition.id }
      expect(response).to be_successful
    end
  end

  describe "GET download_competitor_list_ssv" do
    it "renders" do
      get :download_competitor_list_ssv, params: { competition_id: competition.id }
      assert_equal "text/csv; charset=utf-8", @response.content_type
    end
  end

  describe "GET download_heat_tsv" do
    it "renders data" do
      get :download_heat_tsv, params: { competition_id: competition.id }
      assert_equal "text/csv; charset=utf-8", @response.content_type
    end
  end
end
