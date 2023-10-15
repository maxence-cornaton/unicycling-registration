# == Schema Information
#
# Table name: award_labels
#
#  id            :integer          not null, primary key
#  bib_number    :integer
#  line_2        :string(255)
#  line_3        :string(255)
#  line_5        :string(255)
#  place         :integer
#  user_id       :integer
#  registrant_id :integer
#  created_at    :datetime
#  updated_at    :datetime
#  line_1        :string(255)
#  line_4        :string(255)
#
# Indexes
#
#  index_award_labels_on_user_id  (user_id)
#

class AwardLabelsController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_ability
  before_action :load_award_label, only: %i[edit update destroy]

  before_action :load_user, except: %i[edit update destroy]

  # GET /users/#/award_labels
  def index
    @award_labels = @user.award_labels.includes(:registrant)
    @award_label = AwardLabel.new
  end

  # GET /award_labels/1/edit
  def edit
    @user = @award_label.user
  end

  # POST /users/#/award_labels
  # POST /users/#/award_labels.json
  def create
    @award_label = AwardLabel.new(award_label_params)
    @award_label.user = @user

    respond_to do |format|
      if @award_label.save
        format.html { redirect_to user_award_labels_path(@user), notice: 'Award label was successfully created.' }
      else
        @award_labels = @user.award_labels
        format.html { render action: "index" }
      end
    end
  end

  # PUT /award_labels/1
  # PUT /award_labels/1.json
  def update
    respond_to do |format|
      if @award_label.update(award_label_params)
        format.html { redirect_to user_award_labels_path(@award_label.user), notice: 'Award label was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @award_label.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /award_labels/1
  def destroy
    @user = @award_label.user
    @award_label.destroy
    redirect_to user_award_labels_path(@user)
  end

  # POST /user/:id/award_labels/create_by_competition
  def create_by_competition
    competition = Competition.find(params[:competition_id])
    min_place = 1
    max_place = @config.max_award_place
    n = 0
    competition.competitors.active.each do |competitor|
      competitor.active_members.each do |member|
        n += create_labels_for_competitor(competitor, member.registrant, @user, true, competition.has_experts?, min_place, max_place)
      end
    end
    respond_to do |format|
      format.html { redirect_to user_award_labels_path(@user), notice: "Created #{n} labels." }
    end
  end

  # POST /user/:id/award_labels/create_generic_by_competition
  def create_generic_by_competition
    competition = Competition.find(params[:competition_id])
    min_place = 1
    max_place = @config.max_award_place
    n = 0

    # Age Groups
    if competition.has_age_group_entry_results?
      competition.age_group_entries.each do |age_group_entry|
        (min_place..max_place).each do |place|
          award_label = AwardLabel.new
          award_label.user = current_user
          award_label.populate_generic_age_group_from_competition(competition, age_group_entry, place)
          award_label.save!
          n += 1
        end
      end
    else
      (min_place..max_place).each do |place|
        award_label = AwardLabel.new
        award_label.user = current_user
        award_label.populate_generic_age_group_from_competition(competition, nil, place)
        award_label.save!
        n += 1
      end
    end

    if competition.has_experts?
      ["Male", "Female"].each do |gender|
        (min_place..max_place).each do |place|
          award_label = AwardLabel.new
          award_label.user = current_user
          award_label.populate_generic_expert_from_competition(competition, place, gender)
          award_label.save!
          n += 1
        end
      end
    end

    respond_to do |format|
      format.html { redirect_to user_award_labels_path(@user), notice: "Created #{n} labels." }
    end
  end

  def create_labels
    min_place = set_int_if_present(params[:minimum_place], 1)
    max_place = set_int_if_present(params[:maximum_place], 5)
    age_groups = set_string_if_present(params[:age_groups], false)
    experts    = set_string_if_present(params[:experts], false)

    n = 0
    if params[:registrant_id].present?
      @registrant = Registrant.find(params[:registrant_id])

      @registrant.competitors.each do |competitor|
        n += create_labels_for_competitor(competitor, @registrant, @user, age_groups, experts, min_place, max_place)
      end
    end

    if params[:registrant_group_id].present?
      @registrant_group = RegistrantGroup.find(params[:registrant_group_id])

      @registrant_group.registrant_group_members.includes(:registrant).each do |member|
        member.registrant.competitors.includes(:competition).each do |competitor|
          n += create_labels_for_competitor(competitor, member.registrant, @user, age_groups, experts, min_place, max_place)
        end
      end
    end

    if params[:competition_id].present?
      @competition = Competition.find(params[:competition_id])
      @competition.competitors.each do |competitor|
        competitor.active_members.each do |member|
          n += create_labels_for_competitor(competitor, member.registrant, @user, age_groups, experts, min_place, max_place)
        end
      end
    end

    respond_to do |format|
      format.html { redirect_to user_award_labels_path(@user), notice: "Created #{n} labels." }
    end
  end

  def destroy_all
    @user.award_labels.destroy_all
    redirect_to user_award_labels_path(@user)
  end

  # Create a PDF of labels
  # Optionally specify that we should separate the labels by registrant (which results in reordering the results by registrant)
  # Optionally specify a number of labels to gap on the sheet before printing
  # optionally specify a different label format
  #  Default: Avery5160padded
  #  Options: Avery5293, Avery8293
  #
  def normal_labels
    separate_registrants = false
    unless params[:separate_registrants].nil?
      separate_registrants = true
    end

    label_type = params[:label_type].presence || "Avery8293"

    names = initialize_by_skipped_positions

    if separate_registrants
      labels = @user.award_labels.order(:bib_number)
    else
      labels = @user.award_labels.order(:line_4, :place)
    end

    names += build_names_from_labels(labels, separate_registrants)

    # NOTE: The important part is the "shrink_to_fit" which means that any amount of text will work,
    #  and it will wrap lines as necessary, and then shrink the text.
    # NOTE: The `label_type` must match something in the config/initializers/prawn_labels.rb
    labels = Prawn::Labels.new(names, type: label_type, shrink_to_fit: true) do |pdf, name|
      set_font(pdf)
      pdf.text name, align: :center, inline_format: true, valign: :center
    end
    if params[:show_gridlines].present?
      labels.document.go_to_page(1)
      labels.document.grid.show_all
    end
    result = labels.document.render

    send_data result, filename: "labels-#{Time.current}.pdf", type: "application/pdf"
  end

  def announcer_sheet
    @award_labels = @user.award_labels.reorder(:line_4, :place)

    respond_to do |format|
      format.html {}
      format.pdf { render_common_pdf "announcer_sheet" }
    end
  end

  private

  def load_user
    @user = User.find(params[:user_id])
  end

  def load_award_label
    @award_label = AwardLabel.find(params[:id])
  end

  def authenticate_ability
    authorize current_user, :manage_awards?
  end

  def award_label_params
    params.require(:award_label).permit(:age_group, :bib_number, :line_1, :line_2, :line_3, :line_4, :line_5,
                                        :place, :registrant_id, :user_id)
  end

  def set_int_if_present(value, default)
    if value.present?
      value.to_i
    else
      default
    end
  end

  def set_string_if_present(value, default)
    value.presence || default
  end

  def create_labels_for_competitor(competitor, registrant, user, age_groups, experts, min_place, max_place)
    n = 0
    competition = competitor.competition
    if age_groups
      if create_label(competitor, registrant, false, min_place, max_place, user)
        n += 1
      end
    end

    if experts
      if competition.has_experts?
        if create_label(competitor, registrant, true, min_place, max_place, user)
          n += 1
        end
      end
    end

    n
  end

  def create_label(competitor, registrant, experts, min_place, max_place, my_user)
    if experts || !competitor.competition.has_age_group_entry_results?
      place = competitor.overall_place
    else
      place = competitor.place
    end
    return false if place.nil?
    return false if place.zero?
    return false if place < min_place
    return false if place > max_place

    aw_label = AwardLabel.new
    aw_label.user = my_user
    aw_label.populate_from_competitor(competitor, registrant, experts)

    aw_label.save
  end

  def lines_from_award_label(label)
    lines = ""
    lines += "#{label.line_1}\n" if label.line_1.present?
    lines += "#{label.line_2}\n" if label.line_2.present?
    lines += "#{label.line_3}\n" if label.line_3.present?
    lines += "#{label.line_4}\n" if label.line_4.present?
    lines += "#{label.line_5}\n" if label.line_5.present?
    lines += "<b>#{label.line_6}</b>\n" if label.line_6.present?
    lines
  end

  def initialize_by_skipped_positions
    skip_positions = 0
    if params[:skip_positions].present?
      skip_positions = params[:skip_positions].to_i
    end

    names = []
    skip_positions.times do
      names << ""
    end
    names
  end

  def build_names_from_labels(labels, separate_registrants)
    previous_bib_number = 0
    names = []
    labels.each do |label|
      if separate_registrants && (previous_bib_number != 0 && label.bib_number != previous_bib_number)
        # add 3 blanks
        names << ""
        names << ""
        names << ""
      end
      previous_bib_number = label.bib_number

      names << lines_from_award_label(label)
    end
    names
  end
end

# Monkey-batch Prawn-labels so that I can adjust the expected line-length requirement.
module Prawn
  class Labels
    def shrink_text(record)
      linecount = (split_lines = record.split("\n")).length

      # 15 is estimated max character length per line.
      split_lines.each { |line| linecount += line.length / 13 } # Total hack to make square labels work.

      # -10 accounts for the overflow margins
      rowheight = @document.grid.row_height - 10

      if linecount <= rowheight / 12.floor
        @document.font_size = 12
      else
        @document.font_size = rowheight / (linecount + 1)
      end
    end
  end
end
