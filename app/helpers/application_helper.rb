module ApplicationHelper # rubocop:disable Metrics/ModuleLength
  include ActionView::Helpers::NumberHelper
  include LanguageHelper

  # Devise method invoked after login
  # ensures that the user has a UserConvention record for the current subdomain
  def after_sign_in_path_for(user)
    # Check to see that the user has a user_convention record after they have signed in
    subdomain = Apartment::Tenant.current
    unless user.user_conventions.where(subdomain: subdomain).any?
      flash[:notice] = I18n.t("application.subdomain.welcome", subdomain: subdomain)
      # welcome: Welcome to %{subdomain}
      user.user_conventions.create!(subdomain: subdomain)
    end

    super
  end

  def load_config_object_and_i18n
    @config = EventConfiguration.singleton # rubocop:disable Rails/HelperInstanceVariable
    Time.zone = @config&.time_zone || "Central Time (US & Canada)" # rubocop:disable Rails/HelperInstanceVariable
    set_fallbacks
  end

  def set_i18n_available_locales
    I18n.available_locales = current_config_available_locales
  end

  def current_config_available_locales
    EventConfiguration.all_available_languages & @config.enabled_locales # rubocop:disable Rails/HelperInstanceVariable
  end

  # called by load_config_object_and_i18n
  def set_fallbacks
    fallbacks_hash = {}
    current_config_available_locales.each do |locale|
      fallbacks_hash[locale] = [locale, *(current_config_available_locales - [locale])]
    end
    Globalize.fallbacks = fallbacks_hash
  end

  def log(msg)
    Rails.logger.debug msg
  end

  def setup_registrant_choices(registrant)
    EventChoice.all.each do |ec|
      if registrant.registrant_choices.where(event_choice_id: ec.id).empty?
        registrant.registrant_choices.build(event_choice_id: ec.id)
      end
    end
    Event.all.each do |ev|
      if registrant.registrant_event_sign_ups.select { |resu| resu.event_id == ev.id }.empty?
        registrant.registrant_event_sign_ups.build(event: ev)
      end
      if ev.best_time? && registrant.registrant_best_times.select { |bt| bt.event_id == ev.id }.empty?
        registrant.registrant_best_times.build(event: ev)
      end
    end
    registrant
  end

  def numeric?(val)
    !Float(val).nil?
  rescue StandardError
    false
  end

  def print_formatted_currency(cost)
    ec = EventConfiguration.singleton
    number_to_currency(cost, format: ec.currency, unit: ec.currency_unit)
  end

  def print_item_cost_currency(cost)
    return "Free" if cost == 0.to_money

    print_formatted_currency(cost)
  end

  def organization_membership_label(config)
    organization_type = I18n.t("organization_membership_types.#{config.organization_membership_type}")

    [organization_type, I18n.t("membership_number")].join(" ")
  end

  def print_time_until_prices_increase(reg_cost)
    if EventConfiguration.singleton.online_payment?
      if Time.current > reg_cost.end_date
        I18n.t("prices_increase_soon")
      else
        end_date = distance_of_time_in_words(Time.current, reg_cost.last_day) + " (" + (l reg_cost.last_day, format: :short) + ")"
        I18n.t("prices_increase_at_date", end_date: end_date)
      end
    end
  end

  def text_to_html_linebreaks(text, add_class = nil)
    if add_class
      start_tag = "<p class=\"#{add_class}\">"
    else
      start_tag = '<p>'
    end
    text = text.to_s.dup
    text.gsub!(/\r?\n/, "\n")                     # \r\n and \r => \n
    text.gsub!(/\n\n+/, "</p>\n\n#{start_tag}")   # 2+ newline  => paragraph
    text.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />')  # 1 newline   => br
    text.insert 0, start_tag
    text << "</p>"
  end

  # Allow laptop to access Registration elements and update them (ignore the 'is closed')
  # allow laptop to create user accounts without e-mail confirmation, and auto-login.
  def allow_reg_modifications?
    cookies.signed[:user_permissions] == "yes"
  end

  # Disallow laptop (remove cookies)
  def set_reg_modifications_allowed(allow = true)
    if allow
      cookies.signed[:user_permissions] = {
        value: "yes",
        expires: 24.hours.from_now
      }
    else
      cookies.delete :user_permissions
    end
  end

  def modification_access_key(date = Date.current)
    hash = Digest::SHA256.hexdigest(date.to_s + Rails.configuration.secret_key_base + Apartment::Tenant.current)
    hash.to_i(16) % 1000000
  end

  def skip_user_creation_confirmation?
    override_by_env = Rails.configuration.mail_skip_confirmation
    override_by_env || allow_reg_modifications?
  end

  def new_locale_path(new_locale, existing_path = request.original_fullpath)
    current_locale_prefix = "/#{I18n.locale}/"
    if existing_path.starts_with?(current_locale_prefix)
      "/#{new_locale}/" + existing_path[current_locale_prefix.length..]
    else
      root_path(locale: new_locale)
    end
  end
end
