class CompetitionSetup::CompetitionsController < ApplicationController
  layout "competition_management", except: %i[new create]

  before_action :authenticate_user!
  before_action :load_event, only: %i[create new]
  before_action :load_new_competition, only: %i[create new]
  before_action :load_competition, except: %i[create new]

  before_action :load_event_from_competition, only: [:edit]

  before_action :authorize_competition

  before_action :add_competition_setup_breadcrumb, only: %i[new edit]

  # /events/#/competitions/new
  def new
    add_breadcrumb "New Competition"
    if params[:copy_from]
      attributes = Competition.find(params[:copy_from]).attributes
      @competition.assign_attributes(attributes.except("id"))
    end
  end

  # POST /competitions/#/create
  def create
    if @competition.save
      flash[:notice] = "Competition created successfully"
      redirect_to competition_setup_path
    else
      render :new
    end
  end

  # GET /competitions/1/edit
  def edit
    add_breadcrumb "Edit Competition"
  end

  # PUT /competitions/1
  # PUT /competitions/1.json
  def update
    if @competition.update(competition_params)
      flash[:notice] = 'Competition was successfully updated.'
      redirect_to @competition
    else
      @event = @competition.event
      render :edit
    end
  end

  # DELETE /competitions/1
  # DELETE /competitions/1.json
  def destroy
    @competition.destroy

    redirect_to competition_setup_path
  end

  private

  def authorize_competition
    authorize @competition
  end

  def competition_params
    return {} if params[:competition].blank?

    params.require(:competition).permit(:name, :uses_lane_assignments, :start_data_type, :end_data_type, :base_age_group_type_id,
                                        :age_group_type_id, :scoring_class, :has_experts, :award_title_name,
                                        :award_subtitle_name, :scheduled_completion_at, :num_members_per_competitor,
                                        :penalty_seconds, :automatic_competitor_creation, :combined_competition_id,
                                        :sign_in_list_enabled, :time_entry_columns,
                                        :import_results_into_other_competition,
                                        :hide_max_laps_count, :allow_competitor_creation_during_import_approval,
                                        :score_ineligible_competitors, :results_header,
                                        competition_sources_attributes: %i[id event_category_id gender_filter min_age max_age competition_id max_place _destroy])
  end

  def load_competition
    @competition = Competition.find(params[:id])
  end

  def load_new_competition
    @competition = Competition.new(competition_params)
    @competition&.event = @event
  end

  def load_event_from_competition
    @event ||= @competition.event # rubocop:disable Naming/MemoizedInstanceVariableName
  end

  def load_event
    @event = Event.find(params[:event_id])
  end
end
