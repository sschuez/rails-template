# Command
# rails new \
# --database postgresql \
# -m https://raw.githubusercontent.com/sschuez/rails-template/main/devise.rb \
# CHANGE_THIS_TO_YOUR_RAILS_APP_NAME

run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# GEMFILE
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'devise'
    # gem 'font-awesome-sass'
    gem 'simple_form'
    gem 'cssbundling-rails'
  RUBY
end

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY
  gem 'pry-byebug'
  gem 'pry-rails'
  # gem 'dotenv-rails'
  RUBY
end

# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')







########################################
# AFTER BUNDLE
########################################
after_bundle do

  # Assets
  ########################################
  generate('rail css:install:sass')
  
  run 'rm -rf vendor'
  run 'curl -L https://github.com/sschuez/rails-template/raw/main/stylesheets.zip > stylesheets.zip'
  run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip && mv app/assets/stylesheets app/assets/stylesheets'



  # Generators: db + simple form + pages controller
  ########################################
  rails_command 'db:drop db:create db:migrate'
  generate('simple_form:install', '--bootstrap')
  generate(:controller, 'pages', 'home', '--skip-routes', '--no-test-framework')

  # Replace simple form initializer to work with Bootstrap 5
  run 'curl -L https://raw.githubusercontent.com/heartcombo/simple_form-bootstrap/main/config/initializers/simple_form_bootstrap.rb > config/initializers/simple_form_bootstrap.rb'

  # Routes
  ########################################
  route "root to: 'pages#home'"

  # Git ignore
  ########################################
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Devise install + user
  ########################################
  generate('devise:install')
  generate('devise', 'User')

  # App controller
  ########################################
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
    #{  "protect_from_forgery with: :exception\n" if Rails.version < "5.2"}  before_action :authenticate_user!
    end
  RUBY

  # migrate + devise views
  ########################################
  rails_command 'db:migrate'
  generate('devise:views')

  # Pages Controller
  ########################################
  run 'rm app/controllers/pages_controller.rb'
  file 'app/controllers/pages_controller.rb', <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

  # # Webpacker / Yarn
  # ########################################
  # run 'yarn add bootstrap @popperjs/core'
  # run "rails webpacker:install:stimulus"
  # append_file 'app/javascript/packs/application.js', <<~JS
  #   import "bootstrap"
  # JS

  # inject_into_file 'config/webpack/environment.js', before: 'module.exports' do
  #   <<~JS
  #     // Preventing Babel from transpiling NodeModules packages
  #     environment.loaders.delete('nodeModules');
  #   JS
  # end

  # # Dotenv
  # ########################################
  # run 'touch .env'

  # # Rubocop
  # ########################################
  # run 'curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml'

  # Git
  ########################################
  git add: '.'
  git commit: "-m 'Initial commit with devise template from Stephen's template'"
end