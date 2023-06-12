require "spec_helper"

describe RegistrantPolicy do
  subject { described_class }

  let(:my_user) { FactoryBot.create(:user) }
  let(:my_registrant) { FactoryBot.create(:registrant, user: my_user) }
  let(:other_registrant) { FactoryBot.create(:registrant) }

  let(:ara_readonly) { FactoryBot.create(:additional_registrant_access, user: my_user, accepted_readonly: true) }
  let(:readonly_registrant) { ara_readonly.registrant }

  let(:ara_full_access) { FactoryBot.create(:additional_registrant_access, user: my_user, accepted_readwrite: true) }
  let(:full_access_registrant) { ara_full_access.registrant }

  let(:unconfirmed_ara) { FactoryBot.create(:additional_registrant_access, user: my_user) }
  let(:unconfirmed_shared_registrant) { unconfirmed_ara.registrant }

  permissions :payments? do
    let(:payment_admin) { FactoryBot.create(:payment_admin) }

    it { expect(subject).to permit(payment_admin, my_registrant) }
    it { expect(subject).to permit(my_user, my_registrant) }
    it { expect(subject).not_to permit(my_user, other_registrant) }
  end

  permissions :create? do
    let(:reg_closed?) { false }
    let(:new_reg_closed?) { false }
    let(:authorized_laptop?) { false }
    let(:user) { my_user }
    let(:user_context) { UserContext.new(user, false, reg_closed?, new_reg_closed?, authorized_laptop?) }

    describe "while registration is open" do
      it "allows creation" do
        expect(subject).to permit(user_context, my_registrant)
      end

      context "but new_reg is closed" do
        let(:new_reg_closed?) { true }

        it "disallows creation" do
          expect(subject).not_to permit(user_context, my_registrant)
        end

        describe "on an authorized laptop" do
          let(:authorized_laptop?) { true }

          it { expect(subject).to permit(user_context, my_registrant) }
        end

        describe "as a super_admin" do
          let(:user) { FactoryBot.create(:super_admin_user) }

          it { expect(subject).to permit(user_context, my_registrant) }
        end
      end
    end

    describe "when registration is closed" do
      let(:reg_closed?) { true }
      let(:new_reg_closed?) { true }

      describe "on a normal laptop" do
        it { expect(subject).not_to permit(user_context, my_registrant) }
      end

      describe "on an authorized laptop" do
        let(:authorized_laptop?) { true }

        it { expect(subject).to permit(user_context, my_registrant) }
      end

      describe "as a super_admin" do
        let(:user) { FactoryBot.create(:super_admin_user) }

        it { expect(subject).to permit(user_context, my_registrant) }
      end
    end
  end

  permissions :show? do
    it "allows access to my own registrant" do
      expect(subject).to permit(my_user, my_registrant)
    end

    it "disallows access to another registrant" do
      expect(subject).not_to permit(FactoryBot.create(:user), my_registrant)
    end

    it "allows access to another registrant if I have a additional access permit" do
      expect(subject).to permit(my_user, readonly_registrant)
      expect(subject).to permit(my_user, full_access_registrant)
    end

    it "disallows access to another registrant by me" do
      expect(subject).not_to permit(my_user, other_registrant)
    end

    it "doesn't allow access if not confirmed" do
      expect(subject).not_to permit(my_user, unconfirmed_shared_registrant)
    end

    it "grants access to super_admin" do
      expect(subject).to permit(FactoryBot.create(:super_admin_user), my_registrant)
    end
  end

  permissions :show_contact_details? do
    it "allows access to my own registrant" do
      expect(subject).to permit(my_user, my_registrant)
    end

    it "disallows access to another registrant" do
      expect(subject).not_to permit(FactoryBot.create(:user), my_registrant)
    end

    it "doesn't allow access if readonly" do
      expect(subject).not_to permit(my_user, readonly_registrant)
    end

    it "allows access for readwrite" do
      expect(subject).to permit(my_user, full_access_registrant)
    end

    it "grants access to super_admin" do
      expect(subject).to permit(FactoryBot.create(:super_admin_user), my_registrant)
    end
  end

  describe "within the wizard" do
    let(:reg_closed?) { false }
    let(:authorized_laptop?) { false }
    let(:user) { my_user }
    let(:event_sign_up_closed?) { false }
    let(:config) { double(event_sign_up_closed?: event_sign_up_closed?, volunteer_option: "generic", volunteer?: true, wheel_size_configuration_max_age: 10) }
    let(:user_context) { UserContext.new(user, config, reg_closed?, reg_closed?, authorized_laptop?) }

    permissions :add_volunteers? do
      describe "when event_configuration has volunteers set by default" do
        it { expect(subject).to permit(user_context, FactoryBot.create(:competitor, user: user)) }
      end

      describe "when event_configuration has volunteers disabled" do
        let(:config) { double(event_sign_up_closed?: event_sign_up_closed?, volunteer_option: "none", volunteer?: false) }

        it { expect(subject).not_to permit(user_context, FactoryBot.create(:competitor, user: user)) }
      end
    end

    permissions :add_events? do
      describe "while registration is open" do
        describe "for a non-competitor" do
          it { expect(subject).not_to permit(user_context, FactoryBot.create(:noncompetitor)) }
        end

        describe "for a competitor" do
          it { expect(subject).not_to permit(user_context, FactoryBot.create(:competitor)) }
        end
      end

      describe "when registration is closed" do
        let(:reg_closed?) { true }
        let(:event_sign_up_closed?) { true }

        describe "on a normal laptop" do
          it { expect(subject).not_to permit(user_context, my_registrant) }
        end

        describe "on an authorized laptop" do
          let(:authorized_laptop?) { true }

          it { expect(subject).to permit(user_context, my_registrant) }
        end

        describe "as a super_admin" do
          let(:user) { FactoryBot.create(:super_admin_user) }

          it { expect(subject).to permit(user_context, my_registrant) }
        end
      end

      describe "when registration is closed, but event_sign_up is open" do
        let(:reg_closed?) { true }
        let(:event_sign_up_closed?) { false }

        describe "on a normal laptop" do
          it { expect(subject).to permit(user_context, my_registrant) }
        end

        describe "on an authorized laptop" do
          let(:authorized_laptop?) { true }

          it { expect(subject).to permit(user_context, my_registrant) }
        end

        describe "as a super_admin" do
          let(:user) { FactoryBot.create(:super_admin_user) }

          it { expect(subject).to permit(user_context, my_registrant) }
        end
      end
    end

    permissions :set_wheel_sizes? do
      let(:config) do
        EventConfiguration.singleton.update(start_date: Date.current)
        EventConfiguration.singleton
      end

      describe "for an adult" do
        it { expect(subject).not_to permit(user_context, FactoryBot.create(:registrant, :competitor, :minor, user: my_user, birthday: 11.years.ago)) }
      end

      describe "for a child" do
        it { expect(subject).to permit(user_context, FactoryBot.create(:registrant, :competitor, :minor, user: my_user, birthday: 8.years.ago)) }
      end
    end

    permissions :lodging? do
      let!(:lodging_day) { FactoryBot.create(:lodging_day) }
      let(:config) do
        EventConfiguration.singleton.update(
          lodging_end_date: lodging_end_date
        )
        EventConfiguration.singleton
      end

      context "when lodging date has passed" do
        let(:lodging_end_date) { 1.year.ago }

        it { expect(subject).not_to permit(user_context, my_registrant) }
      end

      context "when lodging date has not passed" do
        let(:lodging_end_date) { 1.year.from_now }

        it { expect(subject).to permit(user_context, my_registrant) }
      end
    end

    permissions :expenses? do
      let!(:item) { FactoryBot.create(:expense_item) }
      let(:config) do
        EventConfiguration.singleton.update(
          add_expenses_end_date: expenses_end_date
        )
        EventConfiguration.singleton
      end

      context "when expenses date has passed" do
        let(:expenses_end_date) { 1.year.ago }

        it { expect(subject).not_to permit(user_context, my_registrant) }
      end

      context "when expenses date has not passed" do
        let(:expenses_end_date) { 1.year.from_now }

        it { expect(subject).to permit(user_context, my_registrant) }
      end
    end
  end
end
