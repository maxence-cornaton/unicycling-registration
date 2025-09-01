class ApplicationPolicy
  attr_reader :user, :record, :comp_reg_closed, :noncomp_reg_closed, :reg_closed_for_limit, :authorized_laptop, :translation_domain
  attr_reader :config

  def initialize(user_context, record)
    if user_context.is_a?(UserContext)
      @user = user_context.user
      @config = user_context.config
      @comp_reg_closed = user_context.comp_reg_closed
      @noncomp_reg_closed = user_context.noncomp_reg_closed
      @reg_closed_for_limit = user_context.reg_closed_for_limit
      @authorized_laptop = user_context.authorized_laptop
      @translation_domain = user_context.translation_domain
    else
      # for ease of testing, we allow passing a non-user context
      # in the actual system, we will always encapsulate the user in a UserContext object
      @user = user_context
      @config = OpenStruct.new(music_submission_ended?: true, wheel_size_configuration_max_age: 10)
      @comp_reg_closed = false
      @noncomp_reg_closed = false
      @reg_closed_for_limit = false
      @authorized_laptop = false
    end

    @user ||= User.new
    @record = record
  end

  def index?
    false
  end

  def show?
    scope.where(id: record.id).exists?
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def rails_admin?(action)
    case action
    when :dashboard
      super_admin?
    when :index
      super_admin?
    when :show
      super_admin?
    when :new
      super_admin?
    when :edit
      super_admin?
    when :update
      super_admin?
    when :destroy
      super_admin?
    when :export
      super_admin?
    when :history
      super_admin?
    when :show_in_app
      super_admin?
    else
      raise ::Pundit::NotDefinedError, "unable to find policy #{action} for #{record}."
    end
  end

  private

  def late_registrant?
    user.has_role?(:late_registrant)
  end

  def data_entry_volunteer?
    user.has_role?(:data_entry_volunteer)
  end

  def data_recording_volunteer?(competition = :any)
    user.has_role?(:data_recording_volunteer, competition)
  end

  def race_official?(competition = :any)
    user.has_role?(:race_official, competition)
  end

  def track_data_importer?(competition)
    user.has_role?(:track_data_importer, competition)
  end

  def membership_admin?
    user.has_role?(:membership_admin)
  end

  def music_dj?
    user.has_role?(:music_dj)
  end

  def event_planner?
    user.has_role?(:event_planner)
  end

  def payment_admin?
    user.has_role?(:payment_admin)
  end

  def all_sites_translator?
    translation_domain
  end

  def translator?
    user.has_role?(:translator)
  end

  def awards_admin?
    user.has_role?(:awards_admin)
  end

  def convention_admin?
    user.has_role?(:convention_admin)
  end

  def competition_admin?
    user.has_role?(:competition_admin)
  end

  def director?(event = :any)
    user.has_role?(:director, event)
  end

  def super_admin?
    user.has_role?(:super_admin)
  end

  def standard_skill_director?
    Event.standard_skill_events.any? { |event| director?(event) }
  end

  # Allows to modify your own records as long as you're a `late_registrant` or registration is still open
  def registration_closed?(competitor_type = nil)
    reg_closed = case competitor_type
                 when "competitor"
                   comp_reg_closed
                 when "noncompetitor"
                   noncomp_reg_closed
                 else
                   comp_reg_closed && noncomp_reg_closed
                 end

    reg_closed && !authorized_laptop && !late_registrant?
  end

  # Are new registrations allowed?
  def new_registration_closed?(competitor_type)
    return true if registration_closed?(competitor_type)

    reg_closed_for_limit
  end

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user_context, scope)
      if user_context.is_a?(UserContext)
        @user = user_context.user
      else
        @user = user_context
      end

      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end

    def super_admin?
      @user && @user.has_role?(:super_admin)
    end
  end
end
