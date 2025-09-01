class PaymentPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user_record? || payment_admin? || super_admin?
  end

  def create?
    user_record? || super_admin?
  end

  def new?
    !registration_closed? || super_admin? # should we prevent this when comp is closed, but noncomp is not?
  end

  %i[create advanced_stripe complete pay_offline apply_coupon].each do |meth|
    define_method("#{meth}?") do
      manage?
    end
  end

  # allow marking a payment as "complete"
  def admin_complete?
    payment_admin? || super_admin?
  end

  delegate :offline_payment?, to: :config

  def summary?
    payment_admin? || super_admin?
  end

  def fake_complete?
    config.test_mode
  end

  private

  def manage?
    return true if super_admin?

    user_record? && (!registration_closed? || payment_admin?) # should we prevent this when comp is closed, but noncomp is not?
  end

  def user_record?
    record.user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.has_role?(:payment_admin) || super_admin?
        scope.all
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
