# == Schema Information
#
# Table name: members
#
#  id                        :integer          not null, primary key
#  competitor_id             :integer
#  registrant_id             :integer
#  created_at                :datetime
#  updated_at                :datetime
#  dropped_from_registration :boolean          default(FALSE), not null
#  alternate                 :boolean          default(FALSE), not null
#
# Indexes
#
#  index_members_competitor_id  (competitor_id)
#  index_members_registrant_id  (registrant_id)
#

class Member < ApplicationRecord
  include CachedSetModel

  belongs_to :competitor, inverse_of: :members
  belongs_to :registrant

  validates :registrant, presence: true
  validate :registrant_once_per_competition

  after_touch :update_min_bib_number
  after_save :update_min_bib_number
  after_destroy :update_min_bib_number

  after_touch :touch_competitor
  after_save :touch_competitor
  after_destroy :touch_competitor

  after_destroy :destroy_orphaned_competitors

  # This is used by the Competitor, in order to update Members
  # without cascading the change back to the Competitor.
  attr_accessor :no_touch_cascade

  def touch_competitor
    return if no_touch_cascade

    comp = competitor.reload
    return if comp.nil?

    competitor.touch
  end

  def self.cache_set_field
    :registrant_id
  end

  # Need to apply this everywhere..for dismount calculation, etc.
  def self.active
    where(alternate: false)
  end

  # validates :competitor, :presence => true # removed for spec tests

  # Should we consider this member dropped?
  # Only do so if they ever dropped, and they are currrently not registered.
  def currently_dropped?
    dropped_from_registration? && !competitor.competition.signed_up_registrants.include?(registrant)
  end

  def to_s
    if alternate
      "#{registrant}(alternate)"
    else
      registrant.to_s
    end
  end

  delegate :club, :state, :country, :ineligible?, :gender, :external_id, :age, to: :registrant

  private

  def registrant_once_per_competition
    if new_record?
      if competitor.nil? || registrant.nil?
        return
      end

      if registrant.competitors.where(competition: competitor.competition).any?
        errors.add(:base, "Cannot have the same registrant (#{registrant}) in the same competition twice")
      end
    end
  end

  def update_min_bib_number
    return if no_touch_cascade

    comp = competitor.reload
    return if comp.nil?

    lowest_bib_number = comp.active_members.includes(:registrant).minimum("registrants.bib_number")
    competitor.update_attribute(:lowest_member_bib_number, lowest_bib_number) if lowest_bib_number
  end

  def destroy_orphaned_competitors
    if competitor&.members&.none?
      competitor.destroy
    end
  end
end
