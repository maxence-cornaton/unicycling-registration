# == Schema Information
#
# Table name: registrant_event_sign_ups
#
#  id                :integer          not null, primary key
#  registrant_id     :integer
#  signed_up         :boolean          default(FALSE), not null
#  event_category_id :integer
#  created_at        :datetime
#  updated_at        :datetime
#  event_id          :integer
#
# Indexes
#
#  index_registrant_event_sign_ups_event_category_id              (event_category_id)
#  index_registrant_event_sign_ups_event_id                       (event_id)
#  index_registrant_event_sign_ups_on_registrant_id_and_event_id  (registrant_id,event_id) UNIQUE
#  index_registrant_event_sign_ups_registrant_id                  (registrant_id)
#

class RegistrantEventSignUp < ApplicationRecord
  before_validation :update_category_if_only_one
  validates :event, :registrant, presence: true
  # The following should be re-enabled? first double-check to see which conventions have violating data.
  # also ensure that flow still works with this. (do we have any events which do not have event_categories?)
  # validates :event_category, :presence => true, :if  => "signed_up"
  validates :signed_up, inclusion: { in: [true, false] } # because it's a boolean
  validate :category_chosen_when_signed_up
  validate :category_in_age_range
  validates :event, presence: true
  validates :event_id, uniqueness: { scope: [:registrant_id] }

  has_paper_trail meta: { registrant_id: :registrant_id }

  belongs_to :registrant, inverse_of: :registrant_event_sign_ups, touch: true
  belongs_to :event_category, touch: true, optional: true
  belongs_to :event

  after_save :auto_create_competitor
  after_save :mark_member_as_dropped
  after_save :create_reg_item

  def self.signed_up
    includes(:registrant).where(registrants: { deleted: false }).where(signed_up: true)
  end

  def event_category_name
    event_category.name.to_s if event.event_categories.size > 1
  end

  # Create a registrantExpenseItem to pay for this event sign up
  def create_reg_item
    return if event.expense_item.blank?

    # clean_registrant, otherwise we get ActiveRecord::ReadOnlyRecord due to the
    # .signed_up scope causing a join
    clean_registrant = Registrant.find(registrant.id)

    if signed_up?
      clean_registrant.build_registration_item(event.expense_item)
    else
      clean_registrant.remove_registration_item(event.expense_item)
    end

    if clean_registrant.valid?
      clean_registrant.save
    end
  end

  delegate :to_s, to: :event_category

  private

  def update_category_if_only_one
    if event.event_categories.size == 1
      if signed_up?
        self.event_category = event.event_categories.first
      else
        self.event_category = nil
      end
    end
  end

  def auto_create_competitor
    if signed_up
      event_category.competitions_being_fed(registrant).each do |competition|
        next unless competition.automatic_competitor_creation?
        next if registrant.competitions.include?(competition)

        competition.create_competitors_from_registrants([registrant], nil)
      end
    end
  end

  def mark_member_as_dropped
    # was signed up and now we are not
    # Find any members which are assigned to competitions, and mark them as "withdrawn"
    if signed_up_before_last_save && saved_change_to_signed_up? && !signed_up
      drop_from_event_category(event_category_id_before_last_save)
    end

    # handle changing category, while still signed up.
    if signed_up && signed_up_before_last_save && saved_change_to_event_category_id? && !event_category_id_before_last_save.nil?
      drop_from_event_category(event_category_id_before_last_save)
    end
  end

  def drop_from_event_category(event_category_id)
    ec = EventCategory.find(event_category_id)
    ec.competitions_being_fed(registrant).each do |competition|
      member = registrant.members.find { |mem| mem.competitor.competition == competition }
      if member
        member.update(dropped_from_registration: true)
        competitor = member.competitor
        if competitor.active? && competition.num_members_per_competitor == "One"
          WithdrawCompetitor.perform(competitor)
        end
      end
    end
  end

  def category_chosen_when_signed_up
    if (signed_up && event_category.nil?) || (!signed_up && event_category.present?)
      errors.add(:base, "Cannot sign up for #{event.name} without choosing a category")
      errors.add(:signed_up, "")
      errors.add(:event_category_id, "")
    end
  end

  def category_in_age_range
    unless event_category.nil? || registrant.nil?
      if signed_up && !event_category.age_is_in_range(registrant.age)
        errors.add(:base, "You must be between #{event_category.age_range_start} and #{event_category.age_range_end}
        years old to select #{event_category.name} for #{event.name} in #{event.category}")
      end
    end
  end
end
