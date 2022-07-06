class ManualPayment
  # this is an admin payment
  #
  # references
  # http://blog.codeclimate.com/blog/2012/10/17/7-ways-to-decompose-fat-activerecord-models/
  # http://stackoverflow.com/questions/972857/multiple-objects-in-a-rails-form
  include Virtus.model

  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  attribute :user, User
  attribute :assign_registrants_user, Boolean
  attribute :created_payment, Payment
  attribute :error_message, String
  validate :at_least_one_paid_element

  def at_least_one_paid_element
    return if unpaid_details.any? { |el| el.pay_for? }

    errors.add(:base, "At least one element must be marked paid for")
  end

  def add_registrant(registrant)
    registrant.owing_registrant_expense_items.each do |rei|
      next if rei.free

      @new_expense_items << ManualPaymentDetail.new(registrant_expense_item_id: rei.id)
    end
  end

  def initialize(params = {})
    @new_expense_items = []
    @error_message = nil
    @assign_registrants_user = false
    params&.each do |name, value|
      send("#{name}=", value)
    end
  end

  def unpaid_details
    @new_expense_items
  end

  def unpaid_details_attributes=(params = {})
    params.values.each do |detail|
      @new_expense_items << ManualPaymentDetail.new(detail)
    end
  end

  def persisted?
    false
  end

  def build_payment_detail(payment, new_detail)
    if new_detail.pay_for
      detail = payment.payment_details.build
      detail.free = new_detail.free
      detail.amount = new_detail.total_cost
      detail.registrant_id = new_detail.registrant_id
      detail.line_item = new_detail.line_item
      detail.details = new_detail.details
    end
  end

  def build_payment
    payment = Payment.new

    unpaid_details.each do |ud|
      build_payment_detail(payment, ud)
    end
    # Assign the user associated with the included payment_details to the payment,
    # instead of assigning the current_user
    if assign_registrants_user
      proposed_user = nil
      payment.payment_details.each do |pd|
        if proposed_user.nil?
          proposed_user = pd.registrant.user
        end
        if proposed_user != pd.registrant.user
          payment.errors.add(:base, "Unable to assign payment when selecting multiple registrants from different users")
        end
        payment.user = proposed_user
      end
    else
      payment.user = user
    end
    payment
  end

  def save
    if invalid?
      self.error_message = "Please choose some elements"
      return false
    end
    payment = build_payment

    if payment.invalid?
      self.error_message = payment.errors.full_messages.join(" ")
      return false
    end

    self.created_payment = payment
    payment.save
  end
end
