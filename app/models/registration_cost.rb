# == Schema Information
#
# Table name: registration_costs
#
#  id              :integer          not null, primary key
#  start_date      :date
#  end_date        :date
#  registrant_type :string           not null
#  onsite          :boolean          default(FALSE), not null
#  current_period  :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_registration_costs_on_current_period                      (current_period)
#  index_registration_costs_on_registrant_type_and_current_period  (registrant_type,current_period)
#

class RegistrationCost < ApplicationRecord
  include CachedModel

  default_scope { order(:start_date) }

  validates :registrant_type, inclusion: { in: RegistrantType::TYPES }
  validates :start_date, :end_date, presence: true
  validates :name, presence: true

  translates :name, fallbacks_for_empty_translations: true
  accepts_nested_attributes_for :translations

  has_many :registration_cost_entries, dependent: :destroy, autosave: true, inverse_of: :registration_cost
  accepts_nested_attributes_for :registration_cost_entries, allow_destroy: true
  has_many :expense_items, through: :registration_cost_entries

  validates :onsite, inclusion: { in: [true, false] } # because it's a boolean

  after_save :clear_cache
  after_destroy :clear_cache

  alias_attribute :to_s, :name

  # ##################### Class-level ##############
  def self.for_type(registrant_type)
    where(registrant_type: registrant_type)
  end

  def self.last_online_period
    reorder(:end_date).where(onsite: false).last
  end

  def self.all_registration_expense_items
    includes(registration_cost_entries: :expense_item).all.flat_map { |rp| rp.expense_items }
  end

  def self.relevant_period(registrant_type, date)
    rp_id = Rails.cache.fetch("/registration_cost/by_date/#{registrant_type}/#{date}")
    cached_rp = find_by(id: rp_id)
    return cached_rp unless cached_rp.nil?

    RegistrationCost.for_type(registrant_type).includes(registration_cost_entries: :expense_item).find_each do |rp|
      if rp.current_period?(date)
        Rails.cache.write("/registration_cost/by_date/#{registrant_type}/#{date}", rp.id, expires_in: 5.minutes)
        return rp
      end
    end
    nil
  end

  def self.current_period
    find_by(current_period: true)
  end

  # determine the appropriate expense_item based on the registrant
  def expense_item_for(registrant)
    registration_cost_entries.find { |rce| rce.valid_for?(registrant.age) }.try(:expense_item)
  end

  # ##################### Instance Level ###########
  # We allow registrations to arrive 1 day _after_ the end date,
  # to account for timezone differences, and 'last minute' shoppers.
  def last_day
    end_date + 1.day
  end

  def current_period?(date = Date.current)
    (start_date <= date && date <= last_day)
  end

  def past_period?(date = Date.current)
    (last_day < date)
  end

  def last_online_period?
    self == RegistrationCost.for_type(registrant_type).last_online_period
  end

  def to_s_with_type
    [registrant_type, to_s].join(" - ")
  end

  private

  def clear_cache
    Rails.cache.delete("/registration_cost/by_date/#{registrant_type}/#{Date.current}")
    RegistrationCostUpdater.new(registrant_type).update_current_period
  end
end
