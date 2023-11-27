class LodgingForm
  include ActiveModel::Model

  attr_accessor :lodging_room_option_id, :registrant_id
  attr_accessor :check_in_day, :check_out_day

  validates :lodging_room_option, :registrant, :check_in_day, :check_out_day, presence: true
  validate :all_desired_days_exist
  validate :meets_minimum_duration

  # create all of the associated registrant_expense_items for the given selection
  def save
    return false unless valid?

    success = true

    Lodging.transaction do
      package = LodgingPackage.new(
        lodging_room_type: lodging_room_type,
        lodging_room_option: lodging_room_option,
        total_cost: lodging_room_option.price * days_to_book.count
      )
      days_to_book.each do |day|
        package.lodging_package_days.build(
          lodging_day: day
        )
      end

      unless package.save
        errors.add(:base, "Unable to save items. #{package.errors.full_messages.join(', ')}")
        success = false
        raise ActiveRecord::Rollback
      end

      # we don't go through the association so that un-saved
      # REI are not still referenced by the registrant on form re-display
      new_rei = RegistrantExpenseItem.new(
        registrant: registrant,
        line_item: package,
        system_managed: true
      )

      unless new_rei.save
        errors.add(:base, "Unable to save items. #{new_rei.errors.full_messages.join(', ')}")
        success = false
        raise ActiveRecord::Rollback
      end
    end

    success
  end

  # Return a set of LodgingForm objects for the lodging currently selected for this registrant
  def self.selected_for(registrant)
    registrant.registrant_expense_items.where(line_item_type: "LodgingPackage").map(&:line_item)
  end

  def self.paid_for(registrant)
    registrant.payment_details.paid.not_refunded.where(line_item_type: "LodgingPackage").map(&:line_item)
  end

  def lodging_room_type
    return nil if lodging_room_option.nil?

    lodging_room_option.lodging_room_type
  end

  def lodging_room_option
    return nil if lodging_room_option_id.blank?

    LodgingRoomOption.joins(lodging_room_type: :lodging)
                     .merge(Lodging.active)
                     .find(lodging_room_option_id)
  end

  private

  def all_desired_days_exist
    return if check_in_day.blank? || check_out_day.blank?

    if days_to_book.first&.date_offered != Date.parse(check_in_day)
      errors.add(:base, "#{check_in_day} Unable to be booked. Out of range?")
    end
    if days_to_book.last&.date_offered != (Date.parse(check_out_day) - 1.day)
      errors.add(:base, "#{check_out_day} Unable to be booked. Out of range?")
    end
  end

  def meets_minimum_duration
    return if lodging_room_type.nil? || lodging_room_type.minimum_duration_days.to_i <= 1

    if days_to_book.count < lodging_room_type.minimum_duration_days
      errors.add(:base, "Must book at least #{lodging_room_type.minimum_duration_days} days for this lodging type")
    end
  end

  def registrant
    Registrant.find(registrant_id)
  end

  # find the LodgingDay objects based on user input
  def days_to_book
    return LodgingDay.none if lodging_room_option.nil?

    lodging_room_option.lodging_days.where(
      LodgingDay.arel_table[:date_offered].gteq(check_in_day)
    ).where(
      LodgingDay.arel_table[:date_offered].lt(check_out_day)
    ).order(LodgingDay.arel_table[:date_offered])
  end
end
