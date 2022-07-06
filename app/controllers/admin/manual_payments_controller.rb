class Admin::ManualPaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_breadcrumbs
  before_action :authorize_payment_admin

  def new
    @registrants = Registrant.order(:bib_number)
  end

  def choose
    add_breadcrumb "Choose Payment Items"

    if params[:registrant_ids].nil?
      redirect_to action: :new
      return
    end

    @manual_payment = ManualPayment.new
    params[:registrant_ids].each do |reg_id|
      registrant = Registrant.find(reg_id)
      @manual_payment.add_registrant(registrant)
    end

    @pending_payments = PaymentDetail.offline_pending.where(registrant_id: params[:registrant_ids]).map(&:payment).flatten.uniq
  end

  def create
    @manual_payment = ManualPayment.new(params[:manual_payment])
    if params[:assign_to_registrant_user]
      @manual_payment.assign_registrants_user = true
    else
      @manual_payment.user = current_user
    end

    if @manual_payment.save
      payment = @manual_payment.created_payment
      redirect_to payment_path(payment), notice: "Created DRAFT payment, please apply coupons and mark as paid"
    else
      add_breadcrumb "Choose Payment Items"
      flash[:alert] = "Error: #{@manual_payment.error_message}"
      redirect_back(fallback_location: new_manual_payment_path)
    end
  end

  private

  def authorize_payment_admin
    authorize current_user, :manage_all_payments?
  end

  def set_breadcrumbs
    add_breadcrumb "Payments Management", summary_payments_path
    add_breadcrumb "New Manual Payment", new_manual_payment_path
  end
end
