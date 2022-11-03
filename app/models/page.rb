# == Schema Information
#
# Table name: pages
#
#  id             :integer          not null, primary key
#  slug           :string           not null
#  created_at     :datetime
#  updated_at     :datetime
#  position       :integer
#  parent_page_id :integer
#  visible        :boolean          default(TRUE), not null
#
# Indexes
#
#  index_pages_on_parent_page_id_and_position  (parent_page_id,position)
#  index_pages_on_position                     (position)
#  index_pages_on_slug                         (slug) UNIQUE
#

class Page < ApplicationRecord
  include CachedModel

  validate :slug_cannot_have_special_characters
  validates :slug, presence: true, uniqueness: true
  validates :title, :body, presence: true

  translates :title, :body, fallbacks_for_empty_translations: true
  accepts_nested_attributes_for :translations

  belongs_to :parent_page, class_name: "Page", optional: true
  has_many :children, class_name: "Page", foreign_key: "parent_page_id"
  has_many :images, class_name: "PageImage", dependent: :destroy

  SPECIAL_SLUGS = ['home', 'privacy-policy'].freeze

  scope :visible, -> { where(visible: true) }

  def self.ordinary
    visible.where.not(slug: SPECIAL_SLUGS)
  end

  def self.parent_or_single
    visible.where(parent_page_id: nil)
  end

  def self.ordered
    order(:position)
  end

  def to_s
    title
  end

  # is this a parent page of other pages?
  def parent?
    children.any?
  end

  private

  def slug_cannot_have_special_characters
    if slug.present? && slug.include?(" ")
      errors.add(:slug, "Slug cannot have spaces")
    end
  end
end
