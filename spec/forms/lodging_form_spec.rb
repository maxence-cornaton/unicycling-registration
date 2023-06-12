require 'spec_helper'

describe LodgingForm do
  let(:competitor) { FactoryBot.create(:competitor) }
  let(:lodging_room_type) { FactoryBot.create(:lodging_room_type) }
  let(:lodging_room_option) { FactoryBot.create(:lodging_room_option, lodging_room_type: lodging_room_type) }
  let(:form) { described_class.new(params) }

  describe "#save" do
    context "with a lodging type with multiple days" do
      let!(:lodging_day1) { FactoryBot.create(:lodging_day, lodging_room_option: lodging_room_option) }
      let!(:lodging_day2) { FactoryBot.create(:lodging_day, lodging_room_option: lodging_room_option) }
      let!(:lodging_day3) { FactoryBot.create(:lodging_day, lodging_room_option: lodging_room_option) }

      describe "when selecting the whole range" do
        let(:params) do
          {
            registrant_id: competitor.id,
            lodging_room_option_id: lodging_room_option.id,
            check_in_day: lodging_day1.date_offered.strftime("%Y/%m/%d"),
            check_out_day: (lodging_day3.date_offered + 1.day).strftime("%Y/%m/%d")
          }
        end

        it "creates registrant_expense_items" do
          expect do
            form.save
          end.to change(RegistrantExpenseItem, :count).by(1)
        end
      end

      context "when the days were created in a non-ascending order" do
        let(:target_date) { Date.current }
        let!(:lodging_day1) { FactoryBot.create(:lodging_day, date_offered: target_date + 2.days, lodging_room_option: lodging_room_option) }
        let!(:lodging_day2) { FactoryBot.create(:lodging_day, date_offered: target_date + 1.day, lodging_room_option: lodging_room_option) }
        let!(:lodging_day3) { FactoryBot.create(:lodging_day, date_offered: target_date, lodging_room_option: lodging_room_option) }

        describe "when selecting the whole range" do
          let(:params) do
            {
              registrant_id: competitor.id,
              lodging_room_option_id: lodging_room_option.id,
              check_in_day: target_date.strftime("%Y/%m/%d"),
              check_out_day: (target_date + 3.days).strftime("%Y/%m/%d")
            }
          end

          it "creates registrant_expense_items" do
            expect do
              form.save
            end.to change(RegistrantExpenseItem, :count).by(1)
          end
        end
      end

      context "when there is a minimum 2 days duration specified on the lodging room type" do
        let(:lodging_room_type) { FactoryBot.create(:lodging_room_type, minimum_duration_days: 2) }

        context "when selecting only a single day" do
          let(:params) do
            {
              registrant_id: competitor.id,
              lodging_room_option_id: lodging_room_option.id,
              check_in_day: lodging_day1.date_offered.strftime("%Y/%m/%d"),
              check_out_day: (lodging_day1.date_offered + 1.day).strftime("%Y/%m/%d")
            }
          end

          it "is not valid" do
            expect(form).not_to be_valid
          end
        end

        context "when selecting 2 days" do
          let(:params) do
            {
              registrant_id: competitor.id,
              lodging_room_option_id: lodging_room_option.id,
              check_in_day: lodging_day1.date_offered.strftime("%Y/%m/%d"),
              check_out_day: (lodging_day1.date_offered + 2.days).strftime("%Y/%m/%d")
            }
          end

          it "is valid" do
            expect(form).to be_valid
          end
        end
      end

      describe "when selecting a single day" do
        let(:params) do
          {
            registrant_id: competitor.id,
            lodging_room_option_id: lodging_room_option.id,
            check_in_day: lodging_day1.date_offered.strftime("%Y/%m/%d"),
            check_out_day: (lodging_day1.date_offered + 1.day).strftime("%Y/%m/%d")
          }
        end

        it "creates only a single registrant_expense_item" do
          expect do
            form.save
          end.to change(RegistrantExpenseItem, :count).by(1)
        end
      end

      describe "When selecting outside of the range" do
        let(:target_date) { (lodging_day1.date_offered - 1.day).strftime("%Y/%m/%d") }
        let(:params) do
          {
            registrant_id: competitor.id,
            lodging_room_option_id: lodging_room_option.id,
            check_in_day: target_date,
            check_out_day: (lodging_day1.date_offered + 1.day).strftime("%Y/%m/%d")
          }
        end

        it "returns an error that it cannot be fulfilled" do
          expect(form.save).to be_falsy
          expect(form.errors.full_messages).to eq(["#{target_date} Unable to be booked. Out of range?"])
        end
      end

      describe "When selecting only outside of the range" do
        let(:target_date) { (lodging_day1.date_offered - 5.days).strftime("%Y/%m/%d") }
        let(:target_date_end) { (lodging_day1.date_offered - 3.days).strftime("%Y/%m/%d") }
        let(:params) do
          {
            registrant_id: competitor.id,
            lodging_room_option_id: lodging_room_option.id,
            check_in_day: target_date,
            check_out_day: target_date_end
          }
        end

        it "returns an error that it cannot be fulfilled" do
          expect(form.save).to be_falsy
          expect(form.errors.full_messages).to eq(
            [
              "#{target_date} Unable to be booked. Out of range?",
              "#{target_date_end} Unable to be booked. Out of range?"
            ]
          )
        end
      end
    end

    context "when the form is not fully filled out" do
      let!(:lodging_day) { FactoryBot.create(:lodging_day, lodging_room_option: lodging_room_option, date_offered: Date.new(2017, 12, 14)) }

      let(:base_params) do
        {
          registrant_id: competitor.id,
          lodging_room_option_id: lodging_room_option.id,
          check_in_day: lodging_day.date_offered.strftime("%Y/%m/%d"),
          check_out_day: (lodging_day.date_offered + 1.day).strftime("%Y/%m/%d")
        }
      end

      context "without a lodging_room_type" do
        let(:params) { base_params.merge(lodging_room_option_id: "") }

        it "returns an error message" do
          expect(form.save).to be_falsy
          expect(form.errors.full_messages).to eq(
            [
              "Lodging room option can't be blank",
              "2017/12/14 Unable to be booked. Out of range?",
              "2017/12/15 Unable to be booked. Out of range?"
            ]
          )
        end
      end

      context "without a start date" do
        let(:params) { base_params.merge(check_in_day: "") }

        it "returns an error message" do
          expect(form.save).to be_falsy
          expect(form.errors.full_messages).to eq(["Check in day can't be blank"])
        end
      end

      context "without a end date" do
        let(:params) { base_params.merge(check_out_day: "") }

        it "returns an error message" do
          expect(form.save).to be_falsy
          expect(form.errors.full_messages).to eq(["Check out day can't be blank"])
        end
      end
    end

    #   context "with a lodging type with a single day, with a maximum" do
    #     before do
    #       lodging_room_type.update!(maximum_available: 1)
    #     end
    #     let!(:lodging_day) { FactoryBot.create(:lodging_day, lodging_room_option: lodging_room_option, date_offered: Date.new(2017, 12, 17)) }

    #     let(:params) do
    #       {
    #         registrant_id: competitor.id,
    #         lodging_room_option_id: lodging_room_option.id,
    #         check_in_day: lodging_day.date_offered.strftime("%Y/%m/%d"),
    #         check_out_day: lodging_day.date_offered.strftime("%Y/%m/%d")
    #       }
    #     end
    #     context "when that day is fully bought" do
    #       let(:existing_package) { FactoryBot.create(:lodging_package) }
    #       let!(:existing_package_day) { FactoryBot.create(:lodging_package_day, lodging_package: lodging_package, lodging_day: lodging_day)}
    #       let!(:registrant_expense_item) { FactoryBot.create(:registrant_expense_item, line_item: lodging_package) }

    #       it "returns falsey" do
    #         expect(form.save).to be_falsy
    #       end

    #       it "has an error message" do
    #         form.save
    #         expect(form.errors.full_messages).to eq(["2017-12-17 Unable to be booked"])
    #       end

    #       it "does not allow buying another day" do
    #         expect do
    #           form.save
    #         end.to change(RegistrantExpenseItem, :count).by(0)
    #       end
    #     end

    #     context "when the day has remaining space" do
    #       it "allows adding the new day" do
    #         expect do
    #           form.save
    #         end.to change(RegistrantExpenseItem, :count).by(1)
    #       end
    #     end
    #   end
    # end

    describe "#selected_for" do
      context "with no selected elements" do
        it "returns a blank array" do
          expect(described_class.selected_for(competitor)).to eq([])
        end
      end

      context "with a single selected element" do
        let!(:lodging_day) { FactoryBot.create(:lodging_day, lodging_room_option: lodging_room_option, date_offered: Date.new(2017, 12, 28)) }
        let(:package) { FactoryBot.create(:lodging_package, lodging_room_option: lodging_room_option, lodging_room_type: lodging_room_option.lodging_room_type) }
        let!(:package_day) { FactoryBot.create(:lodging_package_day, lodging_package: package, lodging_day: lodging_day) }
        let!(:registrant_expense_item) { FactoryBot.create(:registrant_expense_item, registrant: competitor, line_item: package) }

        it "returns a single element array" do
          competitor.reload
          packages = described_class.selected_for(competitor)

          expect(packages.count).to eq(1)
          expect(packages.first.lodging_room_type_id).to eq(lodging_room_type.id)
          expect(packages.first).to eq(package)
        end
      end
    end

    describe "#paid_for" do
      context "with no paid elements" do
        it "returns a blank array" do
          expect(described_class.paid_for(competitor)).to eq([])
        end
      end

      context "with a payment detail" do
        let!(:lodging_day) { FactoryBot.create(:lodging_day, lodging_room_option: lodging_room_option, date_offered: Date.new(2017, 12, 28)) }
        let(:package) { FactoryBot.create(:lodging_package, lodging_room_option: lodging_room_option, lodging_room_type: lodging_room_option.lodging_room_type) }
        let!(:package_day) { FactoryBot.create(:lodging_package_day, lodging_package: package, lodging_day: lodging_day) }
        let!(:payment_detail) { FactoryBot.create(:payment_detail, payment: payment, registrant: competitor, line_item: package) }

        context "with a single unpaid element" do
          let(:payment) { FactoryBot.create(:payment) }

          it { expect(described_class.paid_for(competitor)).to eq([]) }
        end

        context "with a single paid element" do
          let(:payment) { FactoryBot.create(:payment, :completed) }

          it "returns a single element array" do
            competitor.reload
            packages = described_class.paid_for(competitor)

            expect(packages.count).to eq(1)
            expect(packages.first.lodging_room_type_id).to eq(lodging_room_type.id)
            expect(packages.first).to eq(package)
          end
        end
      end
    end
  end
end
