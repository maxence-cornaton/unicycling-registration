# == Schema Information
#
# Table name: uploaded_files
#
#  id             :integer          not null, primary key
#  competition_id :integer          not null
#  user_id        :integer          not null
#  original_file  :string           not null
#  filename       :string           not null
#  content_type   :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_uploaded_files_on_competition_id  (competition_id)
#  index_uploaded_files_on_user_id         (user_id)
#

class UploadedFile < ApplicationRecord
  mount_uploader :original_file, ImportedFileUploader

  belongs_to :user
  belongs_to :competition, optional: true
  validates :filename, presence: true

  scope :ordered, -> { order(:created_at) }
  # Read the params for either
  # 'file' -> Store the file and pass back a reference to the new stored file
  # or
  # 'uploaded_file_id' -> read the stored file
  def self.process_params(params, user:, competition: nil)
    if params[:file].present?
      uploaded_file = UploadedFile.new(user: user)
      uploaded_file.competition = competition if competition.present?
      uploaded_file.original_file = params[:file]
      uploaded_file.filename = params[:file].original_filename
      uploaded_file.save!
      uploaded_file
    elsif params[:uploaded_file_id].present?
      if competition.present?
        competition.uploaded_files.find(params[:uploaded_file_id])
      else
        UploadedFile.find(params[:uploaded_file_id])
      end
    end
  end

  def to_s_with_date
    "#{created_at.to_formatted_s(:short)} - #{filename} (#{user})"
  end
end
