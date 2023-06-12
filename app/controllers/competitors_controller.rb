# == Schema Information
#
# Table name: competitors
#
#  id                       :integer          not null, primary key
#  competition_id           :integer
#  position                 :integer
#  custom_name              :string(255)
#  created_at               :datetime
#  updated_at               :datetime
#  status                   :integer          default(0)
#  lowest_member_bib_number :integer
#  geared                   :boolean          default(FALSE), not null
#  riding_wheel_size        :integer
#  notes                    :string(255)
#  wave                     :integer
#  riding_crank_size        :integer
#
# Indexes
#
#  index_competitors_event_category_id  (competition_id)
#

class CompetitorsController < ApplicationController
  layout "competition_management"
  include SortableObject

  before_action :authenticate_user!
  before_action :load_competition, except: %i[edit update destroy withdraw update_row_order] # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :load_competitor, only:    %i[edit update destroy withdraw update_row_order] # rubocop:disable Rails/LexicallyScopedActionFilter

  before_action :set_parent_breadcrumbs, only: %i[index new edit]
  before_action :authorize_sort, only: :update_row_order # rubocop:disable Rails/LexicallyScopedActionFilter

  # GET /competitions/:competition_id/1/competitors/new
  def new
    add_breadcrumb "Add Competitor"
    @filtered_registrants = @competition.signed_up_registrants
    @competitor = @competition.competitors.new
    authorize @competitor
    @competitor.members.build # add an initial member
  end

  # GET /competitions/1/competitors
  def index
    authorize @competition.competitors.new
    add_breadcrumb "Manage Competitors"
    @registrants = @competition.signed_up_registrants
    @competitors = @competition.competitors.includes(members: [:registrant])
  end

  def add
    authorize @competition.competitors.new

    respond_to do |format|
      raise "No Registrants selected" if params[:registrants].nil?

      regs = Registrant.find(params[:registrants])
      if params[:commit] == Competitor.group_selection_text
        @competition.create_competitor_from_registrants(regs, params[:group_name])
        msg = "Created Group Competitor"
      elsif params[:commit] == Competitor.not_qualified_text
        @competition.create_competitors_from_registrants(regs, "not_qualified")
        msg = "Non-Qualified Competitors created"
      else
        @competition.create_competitors_from_registrants(regs)
        msg = "Created #{regs.count} Competitors"
      end
      format.html { redirect_to competition_competitors_path(@competition), notice: msg }
    rescue Exception => e
      index
      flash.now[:alert] = "Error adding Registrants (0 added) #{e}"
      format.html { render "index" }
    end
  end

  # GET /competitors/1/edit
  def edit
    authorize @competitor

    add_breadcrumb "Edit Competitor"
  end

  def add_all
    authorize @competition.competitors.new

    @competitor = @competition.competitors.new # so that the form renders ok
    respond_to do |format|
      msg = @competition.create_competitors_from_registrants(Registrant.competitor)
      format.html { redirect_to new_competition_competitor_path(@competition), notice: msg }
    rescue Exception => e
      new
      flash.now[:alert] = "Error adding Registrants. #{e}"
      format.html { render "new" }
    end
  end

  # POST /competitors
  # POST /competitors.json
  def create
    @competitor = @competition.competitors.new(competitor_params)
    authorize @competitor
    if @competitor.save
      flash[:notice] = 'Competition registrant was successfully created.'
      respond_to do |format|
        format.html { redirect_to competition_competitors_path(@competition) }
      end
    else
      @registrants = @competition.signed_up_registrants
      flash.now[:alert] = 'Error adding Registrant'
      respond_to do |format|
        format.html { render :new }
      end
    end
  end

  # PUT /competitors/1
  # PUT /competitors/1.json
  def update
    authorize @competitor

    if @competitor.update(competitor_params)
      flash[:notice] = 'Competition registrant was successfully updated.'
      redirect_to competition_competitors_path(@competitor.competition)
    else
      @competition = @competitor.competition
      render :edit
    end
  end

  # DELETE /competitors/1
  # DELETE /competitors/1.json
  def destroy
    authorize @competitor
    @ev_cat = @competitor.competition
    @competitor.destroy
    respond_to do |format|
      format.js {}
      format.html { redirect_to competition_competitors_path(@ev_cat) }
    end
  end

  # PUT /competitors/1/withdraw
  def withdraw
    authorize @competitor
    WithdrawCompetitor.perform(@competitor)
    flash[:notice] = "Competitor #{@competitor} withdrawn"
    redirect_to competition_competitors_path(@competitor.competition)
  end

  # DELETE /events/10/competitors/destroy_all
  def destroy_all
    authorize @competition.competitors.new

    @competition.competitors.destroy_all

    redirect_to new_competition_competitor_path(@competition)
  end

  private

  def authorize_sort
    authorize @competitor, :sort?
  end

  def sortable_object
    Competitor.find(params[:id])
  end

  def competitor_params
    params.require(:competitor).permit(:status, :custom_name, members_attributes: %i[registrant_id id alternate _destroy])
  end

  def load_competition
    @competition = Competition.find(params[:competition_id])
  end

  def load_competitor_through_competition
    @competitor = @competition.competitors.find(params[:id])
  end

  def load_competitor
    @competitor = Competitor.find(params[:id])
  end

  def set_parent_breadcrumbs
    @competition ||= @competitor.competition
    add_competition_setup_breadcrumb
    add_breadcrumb @competition.to_s, competition_path(@competition)
    add_breadcrumb "Manage Competitors", competition_competitors_path(@competition) if @competitor
  end
end
