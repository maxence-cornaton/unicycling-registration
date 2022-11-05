Rails.application.configure do
  config.after_initialize do
    PaperTrail.enabled = false
  end
  # Settings specified here will take precedence over those in config/application.rb.
  config.action_mailer.default_url_options = { host: 'localhost:9292' }

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = true # set to true so that simplecov sees all files

  config.active_record.maintain_test_schema = true

  config.active_record.dump_schema_after_migration = true

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=3600'
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false
  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  config.active_job.queue_adapter = :test

  config.assets.raise_runtime_errors = true

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
end

Rails.configuration.domain = "localhost.dev"
Rails.configuration.mail_full_email = "from@example.com"
Rails.configuration.mail_skip_confirmation = true
Rails.configuration.secret_key_base = "somesecretstringisreallylongenoughtobesecurecheckpassing"
Rails.configuration.error_emails = ["robin+e@dunlopweb.com"]
Rails.configuration.server_admin_email = "robin+admin@dunlopweb.com"
Rails.configuration.ssl_enabled = false
Rails.configuration.instance_creation_code = "this_is_the_code"
