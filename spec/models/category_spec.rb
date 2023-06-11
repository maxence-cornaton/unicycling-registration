# == Schema Information
#
# Table name: categories
#
#  id           :integer          not null, primary key
#  position     :integer
#  created_at   :datetime
#  updated_at   :datetime
#  info_url     :string
#  info_page_id :integer
#

require 'spec_helper'

describe Category do
  it "must have a name" do
    cat = described_class.new
    expect(cat.valid?).to eq(false)
    cat.name = "Track"
    expect(cat.valid?).to eq(true)
  end

  it "has events" do
    cat = FactoryBot.create(:category)
    ev = FactoryBot.create(:event, category: cat)
    expect(cat.events).to eq([ev])
  end

  it "displays its name as to_s" do
    cat = FactoryBot.create(:category)
    expect(cat.to_s).to eq(cat.name)
  end

  describe "with multiple categories" do
    before do
      @category2 = FactoryBot.create(:category)
      @category1 = FactoryBot.create(:category)
      @category1.update_attribute(:position, 1)
    end

    it "lists them in position order" do
      expect(described_class.all).to eq([@category1, @category2])
    end
  end

  it "events should be sorted by position" do
    cat = FactoryBot.create(:category)
    event1 = FactoryBot.create(:event, category: cat)
    event3 = FactoryBot.create(:event, category: cat)
    event2 = FactoryBot.create(:event, category: cat)
    event3.update_attribute(:position, 3)

    expect(cat.events).to eq([event1, event2, event3])
  end

  it "destroy related events upon destroy" do
    cat = FactoryBot.create(:category)
    FactoryBot.create(:event, category: cat)
    expect(Event.all.count).to eq(1)
    cat.destroy
    expect(Event.all.count).to eq(0)
  end

  describe "info_url/info_page" do
    let(:cat) { FactoryBot.create(:category) }

    before do
      cat.update_attribute(:info_page, FactoryBot.create(:page))
      cat.update_attribute(:info_url, nil)
    end

    it "is valid" do
      expect(cat).to be_valid
    end

    it "does allow a blank info_url and a specified info_page" do
      cat.info_url = ""
      expect(cat).to be_valid
    end

    it "doesn't allow setting both info blocks" do
      cat.info_url = "hello"
      expect(cat).to be_invalid
    end
  end
end
