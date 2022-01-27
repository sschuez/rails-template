# Command
# rails new \
# --database postgresql \
# -m https://raw.githubusercontent.com/sschuez/rails-template/main/devise.rb \
# CHANGE_THIS_TO_YOUR_RAILS_APP_NAME

run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# GEMFILE
########################################
# inject_into_file 'Gemfile', before: 'group :development, :test do' do
#   <<~RUBY
#     gem 'devise'
#     # gem 'font-awesome-sass'
#     gem 'simple_form'
#     gem 'cssbundling-rails'
#   RUBY
# end

def rails_version
  @rails_version ||= Gem::Version.new(Rails::VERSION::STRING)
end

def rails_6_or_newer?
  Gem::Requirement.new(">= 6.0.0.alpha").satisfied_by? rails_version
end

def add_gems
  gem 'cssbundling-rails'
  gem 'devise'
  gem 'pundit'
  gem 'jsbundling-rails'
  gem 'simple_form'
end

# inject_into_file 'Gemfile', after: 'group :development, :test do' do
#   <<-RUBY
#   gem 'pry-byebug'
#   gem 'pry-rails'
#   # gem 'dotenv-rails'
#   RUBY
# end

def add_users
  route "root to: 'home#index'"
  generate "devise:install"
  
  # Configure Devise to handle TURBO_STREAM requests like HTML requests
  inject_into_file "config/initializers/devise.rb", "  config.navigational_formats = ['/', :html, :turbo_stream]", after: "Devise.setup do |config|\n"
  
  inject_into_file 'config/initializers/devise.rb', after: "# frozen_string_literal: true\n" do <<~EOF
    class TurboFailureApp < Devise::FailureApp
      def respond
        if request_format == :turbo_stream
          redirect
        else
          super
        end
      end
  
      def skip_format?
        %w(html turbo_stream */*).include? request_format.to_s
      end
    end
  EOF
  end

  inject_into_file 'config/initializers/devise.rb', after: "# ==> Warden configuration\n" do <<-EOF
    config.warden do |manager|
      manager.failure_app = TurboFailureApp
    end
    EOF
  end

  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'development'
  generate :devise, "User", "admin:boolean"

  # Set admin default to false
  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end

  if Gem::Requirement.new("> 5.2").satisfied_by? rails_version
    gsub_file "config/initializers/devise.rb", /  # config.secret_key = .+/, "  config.secret_key = Rails.application.credentials.secret_key_base"
  end
end

def add_authorization
  generate 'pundit:install'
end

def add_jsbundling
  rails_command "javascript:install:esbuild"
end

def add_javascript
  run "yarn add local-time esbuild-rails trix @hotwired/stimulus @hotwired/turbo-rails @rails/activestorage @rails/ujs @rails/request.js"
end

def add_sass
  rails_command "css:install:sass"
end

def copy_templates
  # run 'rm -rf vendor'
  run 'curl -L https://github.com/sschuez/rails-template/raw/main/stylesheets.zip > stylesheets.zip'
  run 'rm app/assets/stylesheets/application.sass.scss'
  run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip' #&& mv app/assets/stylesheets app/assets/stylesheets'
  run 'rm -r app/assets/__MACOSX'
end

def add_simple_form
  rails_command "simple_form:install --bootstrap"

  # Replace simple form initializer to work with Bootstrap 5
  run 'curl -L https://raw.githubusercontent.com/heartcombo/simple_form-bootstrap/main/config/initializers/simple_form_bootstrap.rb > config/initializers/simple_form_bootstrap.rb'

end

def add_esbuild_script
  build_script = "node esbuild.config.js"

  if (`npx -v`.to_f < 7.1 rescue "Missing")
    say %(Add "scripts": { "build": "#{build_script}" } to your package.json), :green
  else
    run %(npm set-script build "#{build_script}")
  end
end

unless rails_6_or_newer?
  puts "Please use Rails 6.0 or newer to create a Jumpstart application"
end

# Main setup
add_gems

after_bundle do
  add_users
  add_authorization
  add_jsbundling
  add_javascript
  
  add_sass
  copy_templates
  add_simple_form
  add_esbuild_script
  
  rails_command "active_storage:install"
  
  # Commit everything to git
  unless ENV["SKIP_GIT"]
    git :init
    git add: "."
    # git commit will fail if user.email is not configured
    begin
      git commit: %( -m 'Initial commit' )
    rescue StandardError => e
      puts e.message
    end
  end

end

# # Dev environment
# ########################################
# gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')







# ########################################
# # AFTER BUNDLE
# ########################################
# after_bundle do

#   # Assets
#   ########################################
#   generate('css:install:sass')
  
#   run 'rm -rf vendor'
#   run 'curl -L https://github.com/sschuez/rails-template/raw/main/stylesheets.zip > stylesheets.zip'
#   run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip && mv app/assets/stylesheets app/assets/stylesheets'



#   # Generators: db + simple form + pages controller
#   ########################################
#   rails_command 'db:drop db:create db:migrate'
#   generate('simple_form:install', '--bootstrap')
#   generate(:controller, 'pages', 'home', '--skip-routes', '--no-test-framework')

#   # Replace simple form initializer to work with Bootstrap 5
#   run 'curl -L https://raw.githubusercontent.com/heartcombo/simple_form-bootstrap/main/config/initializers/simple_form_bootstrap.rb > config/initializers/simple_form_bootstrap.rb'

#   # Routes
#   ########################################
#   route "root to: 'pages#home'"

#   # Git ignore
#   ########################################
#   append_file '.gitignore', <<~TXT
#     # Ignore .env file containing credentials.
#     .env*
#     # Ignore Mac and Linux file system files
#     *.swp
#     .DS_Store
#   TXT

#   # Devise install + user
#   ########################################
#   generate('devise:install')
#   generate('devise', 'User')

#   # App controller
#   ########################################
#   run 'rm app/controllers/application_controller.rb'
#   file 'app/controllers/application_controller.rb', <<~RUBY
#     class ApplicationController < ActionController::Base
#     #{  "protect_from_forgery with: :exception\n" if Rails.version < "5.2"}  before_action :authenticate_user!
#     end
#   RUBY

#   # migrate + devise views
#   ########################################
#   rails_command 'db:migrate'
#   generate('devise:views')

#   # Pages Controller
#   ########################################
#   run 'rm app/controllers/pages_controller.rb'
#   file 'app/controllers/pages_controller.rb', <<~RUBY
#     class PagesController < ApplicationController
#       skip_before_action :authenticate_user!, only: [ :home ]

#       def home
#       end
#     end
#   RUBY

#   # Environments
#   ########################################
#   environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
#   environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

#   # # Webpacker / Yarn
#   # ########################################
#   # run 'yarn add bootstrap @popperjs/core'
#   # run "rails webpacker:install:stimulus"
#   # append_file 'app/javascript/packs/application.js', <<~JS
#   #   import "bootstrap"
#   # JS

#   # inject_into_file 'config/webpack/environment.js', before: 'module.exports' do
#   #   <<~JS
#   #     // Preventing Babel from transpiling NodeModules packages
#   #     environment.loaders.delete('nodeModules');
#   #   JS
#   # end

#   # # Dotenv
#   # ########################################
#   # run 'touch .env'

#   # # Rubocop
#   # ########################################
#   # run 'curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml'

#   # Git
#   ########################################
#   git add: '.'
#   git commit: "-m 'Initial commit with devise template from Stephen's template'"
# end