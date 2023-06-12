require "spec_helper"

describe PaymentMailer do
  before do
    @ec = FactoryBot.create(:event_configuration, long_name: "NAUCC 2140")
  end

  describe "ipn_received" do
    let(:mail) { described_class.ipn_received("something") }

    it "renders the headers" do
      Rails.configuration.error_emails = ["robin+e@dunlopweb.com"]
      expect(mail.subject).to eq("Ipn received")
      expect(mail.to).to eq(["robin+e@dunlopweb.com"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("something")
    end
  end

  describe "coupon_used" do
    let(:payment) { FactoryBot.create(:payment, completed: true) }
    let!(:payment_detail) { FactoryBot.create(:payment_detail, amount: 10, payment: payment) }
    let!(:coupon_code) { FactoryBot.create(:coupon_code, inform_emails: "a@b.c") }
    let!(:payment_detail_coupon_code) do
      FactoryBot.create(:payment_detail_coupon_code,
                        payment_detail: payment_detail,
                        coupon_code: coupon_code)
    end

    it "sends to inform_emails" do
      mail = described_class.coupon_used(payment_detail)
      expect(mail.to).to eq(["a@b.c"])
    end
  end

  describe "payment_completed" do
    let(:payment) { FactoryBot.create(:payment, completed: true) }
    let!(:payment_detail) { FactoryBot.create(:payment_detail, amount: 10, payment: payment) }

    before do
      payment.reload
      Rails.configuration.payment_notice_email = "robin+p@dunlopweb.com"
      @mail = described_class.payment_completed(payment)
    end

    it "renders the headers" do
      expect(@mail.subject).to eq("Payment Completed")
      expect(@mail.to).to eq([payment.user.email])
      expect(@mail.bcc).to eq(["robin+p@dunlopweb.com"])
      expect(@mail.from).to eq(["from@example.com"])
    end

    it "assigns the total_amount" do
      expect(@mail.body).to match(/A payment for \$10.00 USD has been received/)
    end

    it "assigns the full-event-name to @event_name" do
      expect(@mail.body).to match(/NAUCC 2140 - Payment Received/)
    end
  end
end
