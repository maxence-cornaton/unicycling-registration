require 'spec_helper'

describe ChoicesValidator do
  let(:registrant) { FactoryBot.create(:competitor) }

  describe "with a boolean choice event" do
    let(:event) { FactoryBot.create(:event) }
    let(:event_category) { event.event_categories.first }

    let!(:resu) do
      FactoryBot.create(:registrant_event_sign_up, registrant: registrant, event: event, event_category: event_category, signed_up: true)
    end

    it "can describe the event" do
      expect(registrant.describe_event(event)).to eq(event.name)
    end

    context "with a single boolean event choice" do
      let(:boolean_choice) { FactoryBot.create(:event_choice, event: event) }

      it "can select the boolean choice" do
        FactoryBot.create(:registrant_choice, registrant: registrant, event_choice: boolean_choice, value: "1")
        expect(registrant).to be_valid
      end

      it "can be not signed up, with a boolean event_choice" do
        FactoryBot.create(:registrant_choice, registrant: registrant, event_choice: boolean_choice, value: "0")
        resu.update_attribute(:signed_up, false)

        expect(registrant).to be_valid
      end
    end

    describe "and a text field" do
      before do
        @ec2 = FactoryBot.create(:event_choice, event: event, label: "Team", cell_type: "text")
        @rc2 = FactoryBot.create(:registrant_choice, registrant: registrant, event_choice: @ec2, value: "My Team")
      end

      it "can describe the event" do
        expect(registrant.describe_event(event)).to eq("#{event.name} - #{@ec2.label}: #{@rc2.value}")
      end
    end
    # DISABLED because 'multiple' is a deprecated type
    # describe "and a select field" do
    #   before(:each) do
    #     @ec2 = FactoryBot.create(:event_choice, event: event, label: "Category", cell_type: "multiple")
    #     @rc2 = FactoryBot.create(:registrant_choice, registrant: registrant, event_choice: @ec2, value: "Advanced")
    #   end
    #   it "can describe the event" do
    #     expect(registrant.describe_event(event)).to eq("#{event.name} - #{@ec2.label}: #{@rc2.value}")
    #   end
    #   it "doesn't break without a registrant choice" do
    #     @rc2.destroy
    #     expect(registrant.describe_event(event)).to eq("#{event.name}")
    #   end
    # end
  end

  describe "with a single event_choices for an event" do
    before do
      @ev = FactoryBot.create(:event)
      @ec1 = @ev.event_categories.first
    end

    it "is valid without having selection" do
      expect(registrant.valid?).to eq(true)
    end

    it "is valid when having checked off this event" do
      FactoryBot.create(:registrant_event_sign_up, event: @ev, event_category: @ec1, signed_up: true, registrant: registrant)
      expect(registrant.valid?).to eq(true)
    end

    describe "with a second (boolean) event_choice for an event" do
      before do
        @ec2 = FactoryBot.create(:event_choice, event: @ev)
      end

      it "is valid if we only check off the primary_choice" do
        FactoryBot.create(:registrant_event_sign_up, event: @ev, event_category: @ec1, signed_up: true, registrant: registrant)
        registrant.reload
        expect(registrant.valid?).to eq(true)
      end

      it "is valid if we check off both event_choices" do
        registrant.reload
        expect(registrant.valid?).to eq(true)
        FactoryBot.create(:registrant_event_sign_up, event: @ev, event_category: @ec1, signed_up: true, registrant: registrant)
        FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "1", registrant: registrant)
        registrant.reload
        expect(registrant.valid?).to eq(true)
      end

      it "is invalid if we only check off the second_choice" do
        FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "1", registrant: registrant)
        FactoryBot.create(:registrant_event_sign_up, event: @ev, signed_up: false, registrant: registrant)
        registrant.reload
        expect(registrant.valid?).to eq(false)
      end

      it "describes the event" do
        FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "1", registrant: registrant)
        expect(registrant.describe_event(@ev)).to eq("#{@ev.name} - #{@ec2.label}: yes")
      end

      describe "with a text_field optional_if_event_choice to the boolean" do
        before do
          FactoryBot.create(:registrant_event_sign_up, event: @ev, event_category: @ec1, signed_up: true, registrant: registrant)
          @ec3 = FactoryBot.create(:event_choice, event: @ev, cell_type: "text", optional_if_event_choice: @ec2)
          registrant.reload
        end

        it "allows the registrant to NOT specify a value for the text field if the checkbox is selected" do
          FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "1", registrant: registrant)
          FactoryBot.create(:registrant_choice, event_choice: @ec3, value: "", registrant: registrant)
          registrant.reload
          expect(registrant.valid?).to eq(true)
        end

        it "REQUIRES the registrant specify a value for the text field if the checkbox is NOT selected" do
          FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "0", registrant: registrant)
          FactoryBot.create(:registrant_choice, event_choice: @ec3, value: "", registrant: registrant)
          registrant.reload
          expect(registrant.valid?).to eq(false)
        end
      end

      describe "with a text_field required_if_event_choice" do
        before do
          FactoryBot.create(:registrant_event_sign_up, event: @ev, event_category: @ec1, signed_up: true, registrant: registrant)
          @ec3 = FactoryBot.create(:event_choice, event: @ev, cell_type: "text", required_if_event_choice: @ec2)
          registrant.reload
        end

        it "requires the registrant to specify a value for the text field if the checkbox is selected" do
          FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "1", registrant: registrant)
          rc = FactoryBot.create(:registrant_choice, event_choice: @ec3, value: "", registrant: registrant)
          registrant.reload
          expect(registrant.valid?).to eq(false)
          rc.value = "hello"
          rc.save
          registrant.reload
          expect(registrant.valid?).to eq(true)
        end

        it "allows the registrant to NOT specify a value for the text field if the checkbox is NOT selected" do
          FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "0", registrant: registrant)
          FactoryBot.create(:registrant_choice, event_choice: @ec3, value: "", registrant: registrant)
          registrant.reload
          expect(registrant.valid?).to eq(true)
        end
      end
    end

    describe "with a second event_choice (text-style) for an event" do
      before do
        @ec2 = FactoryBot.create(:event_choice, event: @ev, cell_type: "text")
      end

      it "is invalid if we only check off the primary_choice" do
        FactoryBot.create(:registrant_event_sign_up, event: @ev, event_category: @ec1, signed_up: true, registrant: registrant)
        registrant.reload
        expect(registrant.valid?).to eq(false)
      end

      it "is valid if we fill in both event_choices" do
        FactoryBot.create(:registrant_event_sign_up, event: @ev, event_category: @ec1, signed_up: true, registrant: registrant)
        FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "hello there", registrant: registrant)
        registrant.reload
        expect(registrant.valid?).to eq(true)
      end

      it "is valid if we don't choose the event, and we don't fill in the event_choice" do
        FactoryBot.create(:registrant_event_sign_up, event: @ev, signed_up: false, registrant: registrant)
        FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "", registrant: registrant)
        registrant.reload
        expect(registrant.valid?).to eq(true)
      end

      it "is invalid if we fill in only the second_choice" do
        FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "goodbye", registrant: registrant)
        FactoryBot.create(:registrant_event_sign_up, event: @ev, signed_up: false, registrant: registrant)
        registrant.reload
        expect(registrant.valid?).to eq(false)
      end

      describe "if the second choices is optional" do
        before do
          @ec2.optional = true
          @ec2.save!
          registrant.reload
        end

        it "allows empty registarnt_choice" do
          FactoryBot.create(:registrant_event_sign_up, event: @ev, event_category: @ec1, signed_up: true, registrant: registrant)
          FactoryBot.create(:registrant_choice, event_choice: @ec2, value: "", registrant: registrant)
          registrant.reload
          expect(registrant.valid?).to eq(true)
        end
      end
    end
  end
end
