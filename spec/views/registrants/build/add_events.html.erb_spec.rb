require 'spec_helper'

describe "registrants/build/add_events" do
  let(:wizard_path) { "/" }

  before do
    FactoryBot.create(:registration_cost, :competitor,
                      start_date: Date.new(2012, 1, 10),
                      end_date: Date.new(2012, 2, 11))
    FactoryBot.create(:wheel_size_24, id: 3)
    allow(controller).to receive(:current_user) { FactoryBot.create(:user) }
    allow(view).to receive(:wizard_path).and_return(wizard_path)
  end

  describe "the events lists" do
    before do
      @registrant = FactoryBot.build(:competitor)
      FactoryBot.create(:registration_cost,
                        start_date: Date.new(2012, 1, 10),
                        end_date: Date.new(2012, 2, 11))
      @ev1 = FactoryBot.create(:event)
      @categories = [@ev1.category]
    end

    describe "for a boolean choice" do
      before do
        @ec1 = FactoryBot.create(:event_choice, event: @ev1)
        rc = @registrant.registrant_choices.build
        rc.event_choice_id = @ec1.id
      end

      it "has the checkbox" do
        render

        # Run the generator again with the --webrat flag if you want to use webrat matchers
        assert_select "form", action: wizard_path, method: "post" do
          assert_select "input#registrant_registrant_choices_attributes_0_event_choice_id", name: "registrant[registrant_choices_attributes][0][event_choice_id]" do
            assert_select "input[value='#{@ec1.id}']"
          end
          assert_select "input#registrant_registrant_choices_attributes_0_value", name: "registrant[registrant_choices_attributes][0][value]" do
            assert_select "input[value='1']"
          end
        end
      end

      describe "With existing selections" do
        before do
          @rc = FactoryBot.create(:registrant_choice, value: "1", event_choice: @ec1)
          @registrant = @rc.registrant
          @registrant.reload
          @attending = @rc
          @categories = [@rc.event_choice.event.category]

          @ec1 = @rc.event_choice
        end

        it "displays the checkbox as checked off" do
          render

          assert_select "form", action: registrant_path(@registrant), method: "put" do
            assert_select "div[id='tabs']" do
              assert_select "input[type='checkbox']", 2 do
                assert_select "[checked='checked']", 1
              end
            end
            assert_select "label", text: @ec1.event.to_s
          end
        end

        it "renders as not-checked-off if value is '0'" do
          @rc.value = "0"
          @rc.save
          render

          assert_select "form", action: registrant_path(@registrant), method: "put" do
            assert_select "div[id='tabs']" do
              assert_select "input[type='checkbox']", 2 do
                assert_select "[checked='checked']", 0
              end
            end
          end
        end

        it "displays a hidden form field" do
          render

          assert_select "form" do
            assert_select "input[type='hidden'][name='registrant[registrant_choices_attributes][0][value]']"
          end
        end
      end
    end

    describe "for a text choice" do
      before do
        @ec1 = FactoryBot.create(:event_choice, event: @ev1, cell_type: "text", position: 2)
      end

      describe "without a choice selected" do
        before do
          rc = @registrant.registrant_choices.build
          rc.event_choice_id = @ec1.id
        end

        it "has the text input" do
          render

          assert_select "form", action: wizard_path, method: "post" do
            assert_select "input#registrant_registrant_choices_attributes_0_event_choice_id", name: "registrant[registrant_choices_attributes][0][event_choice_id]" do
              assert_select "input[value='#{@ec1.id}']"
            end
            assert_select "input#registrant_registrant_choices_attributes_0_value", name: "registrant[registrant_choices_attributes][0][value]" do
              assert_select "input[type='text']", 1
            end
          end
        end
      end

      describe "for already present choice" do
        before do
          rc = @registrant.registrant_choices.build
          rc.event_choice_id = @ec1.id
          rc.value = "Hello"
        end

        it "displays the text if already present in user's choice" do
          render

          assert_select "input#registrant_registrant_choices_attributes_0_value", name: "registrant[registrant_choices_attributes][0][value]" do
            assert_select "input[type='text'][value='Hello']", 1
          end
        end
      end
    end

    # describe "for multiple choice" do
    #   before(:each) do
    #     @ec1 = FactoryBot.create(:event_choice, event: @ev1, cell_type: "multiple", multiple_values: "one, two, three", position: 2)
    #   end

    #   it "presents me with a select box" do
    #     render

    #     assert_select "#tabs" do
    #       assert_select "select", 1
    #     end
    #   end

    #   it "has the 3+1(blank) values as options" do
    #     render

    #     assert_select "#tabs" do
    #       assert_select "select" do
    #         assert_select "option", 4
    #         assert_select "option[value='one']"
    #         assert_select "option[value='two']"
    #         assert_select "option[value='three']"
    #       end
    #     end
    #   end
    # end

    describe "for a best_time_format" do
      before do
        @ev1.update(best_time_format: "h:mm")
      end

      it "presents me with a text input for the source" do
        render

        assert_select "input#registrant_registrant_best_times_attributes_0_source_location"
        assert_select "input#registrant_registrant_best_times_attributes_0_formatted_value"
      end
    end
  end
end
