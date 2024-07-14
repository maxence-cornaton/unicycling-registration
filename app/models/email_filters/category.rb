class EmailFilters::Category < EmailFilters::BaseEmailFilter
  def self.config
    EmailFilters::SelectType.new(
      filter: "category",
      description: "Users+Registrants who are assigned to any competition in this category",
      possible_arguments: ::Category.all
    )
  end

  def detailed_description
    "Emails of users/registrants associated with any competition in #{category}"
  end

  def filtered_user_emails
    users = registrants.map(&:user)
    users.map(&:email).compact.uniq
  end

  def filtered_registrant_emails
    registrants.map(&:email).compact.uniq
  end

  def registrants
    category.events.map(&:competitor_registrants).flatten
  end

  # object whose policy must respond to `:contact_registrants?`
  def authorization_object
    category
  end

  def valid?
    category
  end

  private

  def category
    ::Category.find(arguments) if arguments.present?
  end
end
