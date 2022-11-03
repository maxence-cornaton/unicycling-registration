# == Schema Information
#
# Table name: feedbacks
#
#  id             :integer          not null, primary key
#  user_id        :integer
#  entered_email  :string
#  message        :text
#  status         :string           default("new"), not null
#  resolved_at    :datetime
#  resolved_by_id :integer
#  resolution     :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  subject        :text
#

class Feedback < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :status, inclusion: { in: %w[new resolved] }

  validates :message, presence: true
  validates :subject, presence: true
  validates :subject, length: { maximum: 100 }
  validates :entered_email, presence: true, unless: :signed_in?
  validates :resolved_at, :resolved_by_id, :resolution, presence: true, if: :resolved?
  validates :entered_email, email_format: true, allow_blank: true

  def resolved?
    status == "resolved"
  end

  def reply_to_email
    entered_email.presence || user.email
  end

  def username
    user.try(:email) || "not-signed-in"
  end

  def user_first_registrant_name
    return "unknown" unless user
    return "##{user.registrants.active.first.bib_number}: #{user.registrants.active.first.name}" if user.registrants.active.count.positive?

    "unknown"
  end

  def resolve
    self.resolved_at = Time.current
    self.status = "resolved"
    save
  end

  private

  def signed_in?
    user.present?
  end
end
