require 'spec_helper'

describe TimeResultPresenter do
  context "from thousands" do
    let(:result) { described_class.from_thousands(62123) }

    it "has the correct thousands" do
      expect(result.thousands).to eq(123)
    end

    it "has the correct seconds" do
      expect(result.seconds).to eq(2)
    end

    it "has the correct minutes" do
      expect(result.minutes).to eq(1)
    end
  end

  describe "when it has a time" do
    let(:minutes) { 19 }
    let(:seconds) { 16 }
    let(:thousands) { 701 }
    let(:result) { described_class.new(minutes, seconds, thousands) }

    it "can print the full time when all values exist" do
      expect(result.full_time).to eq("19:16.701")
    end

    context "when set to default precision" do
      context "with 0 thousands" do
        let(:thousands) { 0 }

        it "should print the thousands even if they are 0" do
          expect(result.full_time).to eq("19:16.000")
        end
      end

      context "with 100 thousands" do
        let(:thousands) { 100 }

        it "should always print tens, if the result is tens" do
          expect(result.full_time).to eq("19:16.100")
        end
      end

      context "with multi-hours of data" do
        let(:minutes) { 200 }
        let(:thousands) { 0 }

        it "should print the hours, for multi-hour events" do
          expect(result.full_time).to eq("3:20:16.000")
        end
      end
    end

    context "when set to hundreds precision" do
      let(:entry_format) { OpenStruct.new(hours?: false, thousands?: false, hundreds?: true, lower_is_better?: true) }
      let(:result) { described_class.new(minutes, seconds, thousands, data_entry_format: entry_format) }

      context "with 0 thousands" do
        let(:thousands) { 0 }

        it "should print the hundreds even if they are 0" do
          expect(result.full_time).to eq("19:16.00")
        end
      end

      context "with 100 thousands" do
        let(:thousands) { 100 }

        it "should always print tens, if the result is tens" do
          expect(result.full_time).to eq("19:16.10")
        end
      end

      context "with multi-hours of data" do
        let(:minutes) { 200 }
        let(:thousands) { 0 }

        it "should print the hours, for multi-hour events" do
          expect(result.full_time).to eq("3:20:16.00")
        end
      end
    end

    context "when set to tens precision" do
      let(:entry_format) { OpenStruct.new(hours?: false, thousands?: false, hundreds?: false, tens?: true, lower_is_better?: true) }
      let(:result) { described_class.new(minutes, seconds, thousands, data_entry_format: entry_format) }

      context "with 0 thousands" do
        let(:thousands) { 0 }

        it "should print the tens even if they are 0" do
          expect(result.full_time).to eq("19:16.0")
        end
      end

      context "with 100 thousands" do
        let(:thousands) { 100 }

        it "should always print tens, if the result is tens" do
          expect(result.full_time).to eq("19:16.1")
        end
      end

      context "with multi-hours of data" do
        let(:minutes) { 200 }
        let(:thousands) { 0 }

        it "should print the hours, for multi-hour events" do
          expect(result.full_time).to eq("3:20:16.0")
        end
      end
    end

    context "with numbers starting with 0" do
      let(:minutes) { 9 }
      let(:seconds) { 6 }
      let(:thousands) { 5 }

      it "can print the full time when the numbers start with 0" do
        expect(result.full_time).to eq("09:06.005")
      end
    end

    context "with more than 60 minutes" do
      let(:minutes) { 61 }
      let(:seconds) { 10 }
      let(:thousands) { 123 }

      it "can print the full time when the minutes are more than an hour" do
        expect(result.full_time).to eq("1:01:10.123")
      end
    end
  end
end
