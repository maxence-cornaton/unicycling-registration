class ExportPolicy < ApplicationPolicy
  def index?
    download_payment_details? || results? || download_events?
  end

  def create?
    return true if super_admin?

    record.exported_by == user
  end

  def show?
    create?
  end

  def download_registrants?
    event_planner? || super_admin?
  end

  def download_competitors_for_timers?
    user.has_role?(:race_official, :any) || competition_admin? || super_admin?
  end

  # This link is on the Registration Overview page
  def download_events?
    event_planner? || super_admin?
  end

  def download_competition_sign_ups?
    download_events?
  end

  def download_payment_details?
    user.has_role?(:export_payment_lists) || super_admin?
  end

  def download_payment_details_by_category?
    download_payment_details?
  end

  def results?
    competition_admin? || super_admin?
  end
end
