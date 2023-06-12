class PaypalPaymentsController < ApplicationController
  before_action :skip_authorization
  skip_before_action :verify_authenticity_token

  # PayPal notification endpoint
  def notification
    process_notification
    head :ok
  end

  # PayPal return endpoint
  def success; end

  private

  def process_notification
    paypal = PaypalConfirmer.new(params, request.raw_post)
    return unless paypal.valid?
    return unless paypal.completed?

    unless paypal.correct_paypal_account?
      PaymentMailer.configuration_error(
        paypal.configured_paypal_email,
        paypal.receiver_email
      ).deliver_later
      return
    end

    if Payment.exists?(invoice_id: paypal.order_number)
      payment = Payment.find_by(invoice_id: paypal.order_number)
      if payment.completed
        PaymentMailer.ipn_received("Payment already completed. Invoice ID: #{paypal.order_number}").deliver_later
      else
        payment.complete(transaction_id: paypal.transaction_id, payment_date: paypal.payment_date)
        PaymentMailer.payment_completed(payment).deliver_later
        if payment.total_amount != paypal.payment_amount.to_money
          PaymentMailer.ipn_received("Payment total #{payment.total_amount} not equal to the paypal amount #{paypal.payment_amount}").deliver_later
        end
      end
    else
      PaymentMailer.ipn_received("Unable to find Payment with Invoice ID #{paypal.order_number}").deliver_later
    end
  end
end
