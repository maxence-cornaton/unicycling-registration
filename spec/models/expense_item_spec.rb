# == Schema Information
#
# Table name: expense_items
#
#  id                     :integer          not null, primary key
#  position               :integer
#  created_at             :datetime
#  updated_at             :datetime
#  expense_group_id       :integer
#  has_details            :boolean          default(FALSE), not null
#  maximum_available      :integer
#  has_custom_cost        :boolean          default(FALSE), not null
#  maximum_per_registrant :integer          default(0)
#  cost_cents             :integer
#  tax_cents              :integer          default(0), not null
#  cost_element_id        :integer
#  cost_element_type      :string
#
# Indexes
#
#  index_expense_items_expense_group_id                          (expense_group_id)
#  index_expense_items_on_cost_element_type_and_cost_element_id  (cost_element_type,cost_element_id) UNIQUE
#

require 'spec_helper'

describe ExpenseItem do
  before do
    @item = FactoryBot.create(:expense_item)
  end

  it "can have the same position but in different expense_groups" do
    eg1 = FactoryBot.create(:expense_group)
    eg2 = FactoryBot.create(:expense_group)
    ei1 = FactoryBot.create(:expense_item, expense_group: eg1)
    ei2 = FactoryBot.create(:expense_item, expense_group: eg2)
    expect(ei1.position).to eq(ei2.position)
    expect(ei2.valid?).to eq(true)
  end

  it "must have tax" do
    @item.tax_cents = nil
    expect(@item.valid?).to eq(false)
  end

  it "can create from factory" do
    expect(@item.valid?).to eq(true)
  end

  describe "With a tax percent of 0" do
    it "has a tax of 0" do
      expect(@item.tax).to eq(0.to_money)
    end

    it "has a total_cost equal to the cost" do
      expect(@item.total_cost).to eq(@item.cost)
    end
  end

  describe "With a tax percentage of 5%" do
    before do
      @item.cost = 100
      @item.tax = 5
    end

    it "has a tax of $5" do
      expect(@item.tax).to eq(5.to_money)
    end

    it "has a total_cost of 5+100" do
      expect(@item.total_cost).to eq(105.to_money)
    end
  end

  describe "with a tax percentage of 5%" do
    it "has no fractional-penny results" do
      @item.cost = 17
      @item.tax = 0.94
      expect(@item.total_cost).to eq(17.94.to_money)
    end
  end

  it "must have a name" do
    @item.name = nil
    expect(@item.valid?).to eq(false)
  end

  it "by default has a normal cost" do
    expect(@item.has_custom_cost).to eq(false)
  end

  it "must have a cost" do
    @item.cost_cents = nil
    expect(@item.valid?).to eq(false)
  end

  it "must have a value for the has_details field" do
    @item.has_details = nil
    expect(@item.valid?).to eq(false)
  end

  it "has a default of no details" do
    item = described_class.new
    expect(item.has_details).to eq(false)
  end

  it "defaults to a tax of 0" do
    item = described_class.new
    expect(item.tax).to eq(0.to_money)
  end

  it "must have a tax >= 0" do
    @item.tax = -1
    expect(@item).to be_invalid
  end

  it "must have an expense group" do
    @item.expense_group = nil
    expect(@item.valid?).to eq(false)
  end

  it "has a decent description" do
    expect(@item.to_s).to eq("#{@item.expense_group} - #{@item.name}")
  end

  it "has not reached the maximum" do
    expect(@item).not_to be_maximum_reached
  end

  it "Can add more entries" do
    expect(@item).to be_can_i_add(1)
  end

  context "When there is a 0-limit set for the maximum available" do
    before { @item.maximum_available = 0 }

    it "has not reached the maximum" do
      expect(@item).not_to be_maximum_reached
    end

    it "Can add more entries" do
      expect(@item).to be_can_i_add(1)
    end
  end

  describe "when an associated payment has been created" do
    before do
      @payment = FactoryBot.create(:payment_detail, line_item: @item)
      @item.reload
    end

    it "is not able to destroy this item" do
      expect(described_class.all.count).to eq(1)
      expect { @item.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
      expect(described_class.all.count).to eq(1)
    end

    it "does not count this entry as a selected_item when the payment is incomplete" do
      expect(@payment.payment.completed).to eq(false)
      expect(@item.num_selected_items).to eq(0)
      expect(@item.num_paid).to eq(0)
      expect(@item.total_amount_paid).to eq(0.to_money)
    end

    it "counts this entry as a selected_item when the payment is complete" do
      pay = @payment.payment
      pay.completed = true
      pay.save!
      expect(@item.num_selected_items).to eq(1)
      expect(@item.num_paid).to eq(1)
      expect(@item.total_amount_paid).to eq(9.99.to_money)
    end
  end

  describe "with an expense_group set for 'noncompetitor_required'" do
    before do
      @rg = FactoryBot.create(:expense_group, noncompetitor_required: true)
    end

    it "can have a first item" do
      @re = FactoryBot.build(:expense_item, expense_group: @rg)
      expect(@re.valid?).to eq(true)
    end

    it "cannot have a second item" do
      @re = FactoryBot.create(:expense_item, expense_group: @rg)
      @rg.reload
      @re2 = FactoryBot.build(:expense_item, expense_group: @rg)
      expect(@re2.valid?).to eq(false)
    end
  end

  describe "with an expense_group set for registration_items" do
    before do
      @rg = FactoryBot.create(:expense_group, :registration)
    end

    it "isn't user_manageable" do
      @re = FactoryBot.create(:expense_item, expense_group: @rg)
      expect(described_class.user_manageable).to eq([@item])
      expect(described_class.all).to match_array([@re, @item])
    end
  end

  describe "with an expense_group set for 'competitor_required'" do
    before do
      @rg = FactoryBot.create(:expense_group, competitor_required: true)
    end

    it "can have a first item" do
      @re = FactoryBot.build(:expense_item, expense_group: @rg)
      expect(@re.valid?).to eq(true)
    end

    it "cannot have a second item" do
      @re = FactoryBot.create(:expense_item, expense_group: @rg)
      @rg.reload
      @re2 = FactoryBot.build(:expense_item, expense_group: @rg)
      expect(@re2.valid?).to eq(false)
    end

    describe "with a pre-existing registrant" do
      before do
        @reg = FactoryBot.create(:competitor)
      end

      it "creates a registrant_expense_item" do
        expect(@reg.registrant_expense_items.count).to eq(0)
        @re = FactoryBot.create(:expense_item, expense_group: @rg)
        @reg.reload
        expect(@reg.registrant_expense_items.count).to eq(1)
        expect(@reg.registrant_expense_items.first.line_item).to eq(@re)
      end

      it "does not create extra entries if the expense_item is updated" do
        expect(@reg.registrant_expense_items.count).to eq(0)
        @re = FactoryBot.create(:expense_item, expense_group: @rg)
        @re.save
        @reg.reload
        expect(@reg.registrant_expense_items.count).to eq(1)
        expect(@reg.registrant_expense_items.first.line_item).to eq(@re)
      end
    end
  end

  describe "with associated registrant_expense_items" do
    before do
      @rei = FactoryBot.create(:registrant_expense_item, line_item: @item)
    end

    it "counts the entry as a selected_item" do
      expect(@item.num_selected_items).to eq(1)
      expect(@item.num_unpaid).to eq(1)
    end

    describe "when the registrant is deleted" do
      before do
        reg = @rei.registrant
        reg.deleted = true
        reg.save!
      end

      it "does not count the expense_item as num_unpaid" do
        expect(@item.num_unpaid).to eq(0)
      end
    end

    describe "when the registrant is not completed filling out their registration form" do
      before do
        reg = @rei.registrant
        reg.status = "events"
        reg.save!
      end

      it "does not count the expense_item as num_unpaid" do
        expect(@item.num_unpaid).to eq(0)
      end

      it "counts the expense_item as num_unpaid when option is selected" do
        expect(@item.num_unpaid(include_incomplete_registrants: true)).to eq(1)
      end
    end
  end

  describe "when associated with an event" do
    let(:event) { FactoryBot.create(:event, name: "The Event") }
    let(:expense_item) { FactoryBot.create(:expense_item, cost_element: event) }

    it "describes the name of the expense_item based on the name of the event" do
      expect(expense_item.to_s).to eq("The Event")
    end
  end

  describe "when a registration has a registration_cost" do
    before do
      @comp_reg_cost = FactoryBot.create(:registration_cost, :competitor, expense_item: @item)
      @noncomp_reg_cost = FactoryBot.create(:registration_cost, :noncompetitor)
      @nc_item = @noncomp_reg_cost.expense_items.first
    end

    describe "with a single competitor" do
      before do
        @reg = FactoryBot.create(:competitor)
      end

      it "lists the item as un_paid" do
        expect(@item.num_unpaid).to eq(1)
        expect(@nc_item.num_unpaid).to eq(0)
      end
    end

    describe "with a single non_competitor" do
      before do
        @nc_reg = FactoryBot.create(:noncompetitor)
      end

      it "counts the nc item only" do
        expect(@nc_item.num_unpaid).to eq(1)
        expect(@item.num_unpaid).to eq(0)
      end
    end
  end
end
