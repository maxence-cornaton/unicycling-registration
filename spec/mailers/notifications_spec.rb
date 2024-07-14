require "spec_helper"

describe Notifications do
  before do
    @ec = FactoryBot.create(:event_configuration, long_name: "NAUCC 2140", contact_email: "guy@convention.com")
  end

  describe "request_registrant_access" do
    let(:mail) do
      described_class.request_registrant_access(FactoryBot.create(:registrant, first_name: "Billy", last_name: "Johnson"),
                                                FactoryBot.create(:user, email: "james@dean.com"))
    end

    it "identifies the person making the request" do
      expect(mail.body).to match(/james@dean.com has requested permission to view the registration record of Billy Johnson/)
    end
  end

  describe "registrant_access_accepted" do
    let(:mail) do
      described_class.registrant_access_accepted(FactoryBot.create(:registrant, first_name: "Billy", last_name: "Johnson"),
                                                 FactoryBot.create(:user, email: "james@dean.com"))
    end

    it "identifies the accetance of the request" do
      expect(mail.body).to match(/Your request for access to the registration of Billy Johnson has been accepted/)
    end
  end

  describe "send_mass_email" do
    let(:mail) do
      described_class.send_mass_email("subejct", "Body", ["a@b.com"], "abc123")
    end

    it "sets the reply-to address" do
      expect(mail.reply_to).to match(["guy@convention.com"])
    end
  end

  describe "send_feedback" do
    let(:feedback) { FactoryBot.create(:feedback, message: "This is some feedback", entered_email: "test@complaint.com") }
    let(:mail) do
      described_class.send_feedback(feedback.id)
    end

    it "sets the reply-to address" do
      expect(mail.reply_to).to match(["test@complaint.com"])
    end

    it "sends the email to the event_configuration contact person" do
      expect(mail.to).to match(["guy@convention.com"])
    end

    it "sets the exception emailer targets as CC" do
      expect(mail.cc).to match(["robin+e@dunlopweb.com"])
    end

    describe "with a signed in user without specifying an e-mail" do
      let(:feedback) { FactoryBot.create(:feedback, message: "other feedback", user: nil, entered_email: "test@email.com") }

      it "sets the reply to address" do
        expect(mail.reply_to).to match(["test@email.com"])
      end
    end
  end
end
