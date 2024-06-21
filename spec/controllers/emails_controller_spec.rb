require 'spec_helper'

describe EmailsController do
  before do
    @user = FactoryBot.create(:super_admin_user)
    sign_in @user
  end

  describe "GET index" do
    it "can view the page" do
      get :index
      expect(response).to be_successful
    end
  end

  describe "GET list" do
    it "can view the page" do
      get :list, params: { filter_email: { filter: "confirmed_accounts" } }
      expect(response).to be_successful
    end
  end

  describe "GET download" do
    it "can view the page" do
      get :download
      expect(response).to be_successful
    end
  end

  describe "GET sent" do
    it "can view the page" do
      mass_email = FactoryBot.create(:mass_email)
      get :sent, params: { id: mass_email.id }
      expect(response).to be_successful
    end
  end

  describe "GET all_sent" do
    it "can view the page" do
      get :all_sent
      expect(response).to be_successful
    end
  end

  describe "POST send_email" do
    it "can send an e-mail" do
      FactoryBot.create(:user)
      ActionMailer::Base.deliveries.clear
      post :create, params: { email: { subject: "Hello werld", body: "This is the body" }, filter: "confirmed_accounts", arguments: "" }
      num_deliveries = ActionMailer::Base.deliveries.size
      expect(num_deliveries).to eq(1)
      expect(MassEmail.count).to eq(1)
      message = ActionMailer::Base.deliveries.first
      expect(message.bcc.count).to eq(2)
    end

    it "breaks apart large requests into multiple smaller requests" do
      FactoryBot.create_list(:user, 50)
      ActionMailer::Base.deliveries.clear
      post :create, params: { email: { subject: "Hello werld", body: "This is the body" }, filter: "confirmed_accounts", arguments: "" }
      num_deliveries = ActionMailer::Base.deliveries.size
      expect(num_deliveries).to eq(2)

      first_message = ActionMailer::Base.deliveries.first
      expect(first_message.bcc.count).to eq(40)

      second_message = ActionMailer::Base.deliveries.second
      expect(second_message.bcc.count).to eq(11) # 10 remaining from 50, plus 1 super_admin (self)
    end
  end
end
