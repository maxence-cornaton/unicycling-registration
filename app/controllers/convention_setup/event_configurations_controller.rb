# == Schema Information
#
# Table name: event_configurations
#
#  id                                    :integer          not null, primary key
#  event_url                             :string(255)
#  start_date                            :date
#  contact_email                         :string(255)
#  artistic_closed_date                  :date
#  standard_skill_closed_date            :date
#  event_sign_up_closed_date             :date
#  created_at                            :datetime
#  updated_at                            :datetime
#  test_mode                             :boolean          default(FALSE), not null
#  comp_noncomp_url                      :string(255)
#  standard_skill                        :boolean          default(FALSE), not null
#  usa                                   :boolean          default(FALSE), not null
#  iuf                                   :boolean          default(FALSE), not null
#  currency_code                         :string(255)
#  rulebook_url                          :string(255)
#  style_name                            :string(255)
#  custom_waiver_text                    :text
#  music_submission_end_date             :date
#  artistic_score_elimination_mode_naucc :boolean          default(TRUE), not null
#  usa_individual_expense_item_id        :integer
#  usa_family_expense_item_id            :integer
#  logo_file                             :string(255)
#  max_award_place                       :integer          default(5)
#  display_confirmed_events              :boolean          default(FALSE), not null
#  spectators                            :boolean          default(FALSE), not null
#  usa_membership_config                 :boolean          default(FALSE), not null
#  paypal_account                        :string(255)
#  waiver                                :string(255)      default("none")
#  validations_applied                   :integer
#  italian_requirements                  :boolean          default(FALSE), not null
#  rules_file_name                       :string(255)
#  accept_rules                          :boolean          default(FALSE), not null
#  paypal_mode                           :string(255)      default("disabled")
#  offline_payment                       :boolean          default(FALSE), not null
#  enabled_locales                       :string           default("en,fr"), not null
#  comp_noncomp_page_id                  :integer
#  under_construction                    :boolean          default(TRUE), not null
#

class ConventionSetup::EventConfigurationsController < ConventionSetup::BaseConventionSetupController
  before_action :authenticate_user!
  before_action :load_event_configuration
  before_action :authorize_cache, only: %i[cache clear_cache clear_counter_cache]
  before_action :authorize_advanced_settings, only: [:advanced_settings] # rubocop:disable Rails/LexicallyScopedActionFilter

  EVENT_CONFIG_PAGES = %i[registrant_types rules_waiver name_logo organization_membership important_dates registration_questions volunteers payment_settings advanced_settings go_live].freeze

  before_action :authorize_convention_setup, only: EVENT_CONFIG_PAGES

  EVENT_CONFIG_PAGES.each do |page|
    define_method("update_#{page}") do
      authorize_convention_setup
      update(page)
    end
    before_action "set_#{page}_breadcrumbs".to_sym, only: ["update_#{page}".to_sym, page.to_s.to_sym]
    define_method("set_#{page}_breadcrumbs") do
      add_breadcrumb page.to_s.humanize
    end
  end

  def cache; end

  def clear_cache
    Rails.cache.clear
    flash[:notice] = "Cache cleared"
    redirect_to cache_event_configuration_path
  end

  def clear_counter_cache
    EventConfiguration.reset_counter_caches
    flash[:notice] = "Counter cache cleared"
    redirect_to cache_event_configuration_path
  end

  # Toggle a role for the current user
  # Only enabled when the TEST_MODE flag is set
  def test_mode_role
    authorize @event_configuration
    role = params[:role]

    if User.changable_user_roles.include?(role.to_sym)
      if current_user.has_role? role
        current_user.remove_role role
      else
        current_user.add_role role
      end

      flash[:notice] = 'User Permissions successfully updated.'
    else
      flash[:alert] = "Unable to set role"
    end
    redirect_back(fallback_location: root_path)
  end

  private

  # prevent non-super-admin from accessing advanced-settings page
  def authorize_advanced_settings
    authorize @event_configuration, :advanced_settings?
  end

  def authorize_cache
    authorize @event_configuration, :manage_cache?
  end

  def authorize_convention_setup
    authorize @event_configuration, :setup_convention?
  end

  def update(page)
    @event_configuration.assign_attributes(send("#{page}_params"))
    @event_configuration.apply_validation(page)
    if @event_configuration.save
      redirect_to convention_setup_path, notice: 'Event configuration was successfully updated.'
    else
      render action: page
    end
  end

  def load_event_configuration
    @event_configuration = EventConfiguration.singleton
  end

  def registrant_types_params
    params.require(:event_configuration).permit(:spectators, :noncompetitors,
                                                :competitor_benefits, :noncompetitor_benefits, :spectator_benefits,
                                                :comp_noncomp_url, :comp_noncomp_page_id, :max_registrants)
  end

  def rules_waiver_params
    params.require(:event_configuration).permit(:waiver, :waiver_url, :custom_waiver_text,
                                                :accept_rules, :rules_file_name, :waiver_file_name,
                                                :request_address, :request_emergency_contact,
                                                :request_responsible_adult,
                                                :rulebook_url)
  end

  def registration_questions_params
    params.require(:event_configuration).permit(:request_address, :request_emergency_contact,
                                                :request_responsible_adult,
                                                :require_medical_certificate,
                                                :medical_certificate_info_page_id,
                                                :standard_skill, :representation_type,
                                                :registrants_should_specify_default_wheel_size)
  end

  def volunteers_params
    params.require(:event_configuration).permit(:volunteer_option, :volunteer_option_page_id)
  end

  def advanced_settings_params
    params.require(:event_configuration).permit(:italian_requirements,
                                                :iuf,
                                                :test_mode, :usa,
                                                :display_confirmed_events,
                                                :add_event_end_date,
                                                :imported_registrants)
  end

  def name_logo_params
    params.require(:event_configuration).permit(:long_name,
                                                :short_name,
                                                :logo_file,
                                                :dates_description,
                                                :event_url,
                                                :location,
                                                :contact_email,
                                                :style_name,
                                                enabled_locales: [])
  end

  def organization_membership_params
    params.require(:event_configuration).permit(:organization_membership_type)
  end

  def payment_settings_params
    params.require(:event_configuration).permit(
      :paypal_account,
      :payment_mode,
      :stripe_public_key,
      :stripe_secret_key,
      :offline_payment,
      :offline_payment_description,
      :currency,
      :currency_code
    )
  end

  def important_dates_params
    params.require(:event_configuration).permit(
      :standard_skill_closed_date,
      :artistic_closed_date,
      :music_submission_end_date,
      :event_sign_up_closed_date,
      :start_date,
      :age_calculation_base_date,
      :lodging_end_date,
      :add_expenses_end_date
    )
  end

  def go_live_params
    params.require(:event_configuration).permit(:under_construction)
  end
end
