# == Schema Information
#
# Table name: payments
#
#  id                   :integer          not null, primary key
#  user_id              :integer
#  completed            :boolean          default(FALSE), not null
#  cancelled            :boolean          default(FALSE), not null
#  transaction_id       :string
#  completed_date       :datetime
#  created_at           :datetime
#  updated_at           :datetime
#  payment_date         :string
#  note                 :string
#  invoice_id           :string
#  offline_pending      :boolean          default(FALSE), not null
#  offline_pending_date :datetime
#
# Indexes
#
#  index_payments_user_id  (user_id)
#

class Payment < ApplicationRecord
  include CachedModel

  scope :completed, -> { where(completed: true) }
  scope :completed_or_offline, -> { where("completed = TRUE or offline_pending = TRUE") }
  scope :offline_pending, -> { where(offline_pending: true) }

  validates :user, presence: true
  validate :transaction_id_or_note
  validates_associated :payment_details

  has_paper_trail

  belongs_to :user
  has_many :payment_details, inverse_of: :payment, dependent: :destroy
  accepts_nested_attributes_for :payment_details, reject_if: proc { |attributes| attributes['registrant_id'].blank? }, allow_destroy: true

  before_validation :set_invoice_id
  validates :invoice_id, presence: true, uniqueness: true

  after_save :update_registrant_items
  after_save :touch_payment_details
  after_save :inform_of_coupons

  def completed_or_offline?
    completed? || offline_pending?
  end

  def details
    return "(Offline Payment Pending)" if offline_pending?

    if transaction_id.present?
      return transaction_id
    end

    if note.present?
      return note
    end

    nil
  end

  def complete(options = {})
    assign_attributes(options)
    self.completed_date = Time.current
    self.completed = true
    self.offline_pending = false
    save
  end

  # return a set of payment_details which are unique With-respect-to {amount, expense_item }
  def unique_payment_details
    results = []
    payment_details.each do |pd|
      res = nil
      results.each do |r|
        if r.line_item_id == pd.line_item_id && r.line_item_type == pd.line_item_type && r.amount == pd.amount
          res = r
          break
        end
      end

      if res.nil?
        results << PaymentDetailSummary.new(line_item_id: pd.line_item_id, line_item_type: pd.line_item_type, count: 1, amount: pd.amount)
      else
        res.count += 1
      end
    end
    results
  end

  # describe the payment, in succint form
  # by only describing the members
  def description
    payment_details.map(&:registrant).compact.uniq.map do |reg|
      reg.with_id_to_s
    end.join(", ")
  end

  def long_description
    payment_details.map do |pd|
      next if pd.amount == 0.to_money

      "##{pd.registrant.bib_number} #{pd} (#{pd.amount.format(separator: '.', symbol: nil, thousands_separator: nil)})"
    end.compact.join(", ")
  end

  def paypal_post_url
    "#{EventConfiguration.paypal_base_url}/cgi-bin/webscr"
  end

  def total_amount
    Money.new(payment_details.reduce(0.to_money) { |memo, pd| memo + pd.cost })
  end

  def self.total_refunded_amount
    total = 0.to_money
    PaymentDetail.refunded.includes(:payment, refund_detail: :refund).find_each do |payment_detail|
      total += payment_detail.cost
    end
    total
  end

  def self.total_received
    total = 0.to_money
    Payment.includes(payment_details: [refund_detail: :refund]).completed.each do |payment|
      total += payment.total_amount
    end
    total
  end

  def self.paid_details
    all = []
    Registrant.all.find_each do |reg|
      all += reg.paid_details
    end
    all
  end

  def self.build_from_details(options)
    payment = Payment.new(
      completed: true,
      note: options[:note],
      completed_date: Time.current
    )
    payment.payment_details.build(
      registrant: options[:registrant],
      line_item: options[:item],
      details: options[:details],
      amount: options[:amount],
      free: false
    )
    payment
  end

  private

  def transaction_id_or_note
    if completed?
      if details.nil?
        errors.add(:base, "Transaction ID or Note must be filled in")
      end
    end
  end

  def set_invoice_id
    self.invoice_id ||= SecureRandom.hex(10)
  end

  def touch_payment_details
    payment_details.each do |pd|
      pd.touch
    end
  end

  # When a payment is completed (or marked as offline_pending)
  # we want to remove the matching RegistrantExpenseItems, which
  # results in "Locking" the registrant to this payment/combination
  def update_registrant_items
    return true if offline_payment_now_completed?
    return true unless just_completed_or_offline_payment?

    payment_details.each do |pd|
      rei = RegistrantExpenseItem.find_by(registrant_id: pd.registrant.id, line_item: pd.line_item, free: pd.free, details: pd.details)
      unless pd.details.nil?
        if rei.nil? && pd.details.empty?
          rei = RegistrantExpenseItem.find_by(registrant_id: pd.registrant.id, line_item: pd.line_item, free: pd.free, details: nil)
        end
      end

      if rei.nil?
        # this is used when PayPal eventually approves a payment, but the registration
        # period has moved forward, and we have changed the associated registration_item?
        all_reg_items = RegistrationCost.all_registration_expense_items
        if all_reg_items.include?(pd.line_item)
          # the pd is a reg_item, see if there is another reg_item in the registrant's list
          rei = pd.registrant.registration_item
        end
      end

      if rei.nil?
        PaymentMailer.missing_matching_expense_item(id).deliver_later
      else
        rei.destroy
      end
    end
  end

  # Send an e-mail that a coupon was used, for any payment_details which used coupons
  def inform_of_coupons
    return true if offline_payment_now_completed?
    return true unless just_completed_or_offline_payment?

    payment_details.map(&:inform_of_coupon)
  end

  # Has this pamyent just transitioned into offline_payment or into completed?
  def just_completed_or_offline_payment?
    (completed? && saved_change_to_completed?) || (offline_pending? && saved_change_to_offline_pending?)
  end

  # has an offline payment now transitioned to completed?
  def offline_payment_now_completed?
    offline_pending_before_last_save && (completed? && saved_change_to_completed?)
  end
end
