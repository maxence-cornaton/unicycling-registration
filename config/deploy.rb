set :eye_env, -> { { rails_env: fetch(:rails_env) } }
set :application, 'unicycling-registration'
set :repo_url, 'git@github.com:rdunlop/unicycling-registration.git'
set :stages, %w[prod]

# Default value for :linked_files is []
set :linked_files, %w[.env.local config/eye.yml public/robots.txt]

# Default value for linked_dirs is []
# .well-known is for letsencrypt
set :linked_dirs, %w[bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/sitemaps public/.well-known]

namespace :deploy do
  task install_translations: [:set_rails_env] do
    on primary(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "import_translations_from_yml"
          execute :rake, "write_tolk_to_disk"
        end
      end
    end
  end
end
after 'deploy:published', 'deploy:install_translations'

# rubocop:disable Rails/Output
namespace :translation do
  task :download do
    local_diff = `git status --untracked-files=no --porcelain`
    on primary(:app) do
      if local_diff.empty?
        FileUtils.rm_rf "config/locales"
        download! "#{release_path}/config/locales/", "config/", recursive: true
      else
        puts "****** ERROR *******"
        puts "For safety purposes you cannot run this with a dirty local git directory"
        puts "Changes local:"
        puts local_diff.to_s
      end
    end
  end
end
# rubocop:enable Rails/Output

set :whenever_command,      -> { %i[bundle exec whenever] }
set :whenever_environment,  -> { fetch :rails_env }
set :whenever_identifier,   -> { fetch :application }
set :whenever_roles,        -> { %i[db app] }

set :rollbar_token, ENV["ROLLBAR_ACCESS_TOKEN"]
set :rollbar_env, proc { fetch :rails_env }
set :rollbar_role, proc { :app }
