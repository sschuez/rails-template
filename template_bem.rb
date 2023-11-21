# Command
# rails new \
# --database postgresql \
# -m https://raw.githubusercontent.com/sschuez/rails-template/main/template.rb \
# CHANGE_THIS_TO_YOUR_RAILS_APP_NAME

def add_gems
  gem 'devise'#, github: "heartcombo/devise", branch: "main"
  gem 'pundit'
  gem "dartsass-rails"
  gem 'simple_form'
  
  gem_group :development, :test do
    gem "rspec-rails"
    gem "factory_bot_rails"
  end

  gem_group :test do
    gem 'pundit-matchers'
    gem 'capybara'
    gem 'database_cleaner'
  end
end

def add_users
  route "root to: 'pages#home'"
  generate "devise:install"
  generate "devise:views"

  generate :devise, "User", "admin:boolean"

  # Set admin default to false
  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end
end

def add_authorization
  generate 'pundit:install'
end

def add_dartsass_rails
  rails_command "./bin/bundle add dartsass-rails"
  rails_command "./bin/rails dartsass:install"  
  run "rm app/assets/stylesheets/application.css"
  gsub_file('app/assets/stylesheets/application.scss', '// Sassy', '// Mixins
@use "mixins/media";

// Configuration
@use "config/variables";
@use "config/reset";
@use "config/animations";

// Components
@use "components/btn";
@use "components/empty_state";
@use "components/error_message";
@use "components/flash";
@use "components/footer";
@use "components/form";
@use "components/navbar";
@use "components/turbo_progress_bar";
@use "components/visually_hidden";

// Layouts
@use "layouts/container";
@use "layouts/header";

// Utilities
@use "utilities/margins";

// External Libraries
// @import "bootstrap";
// @import url("https://cdn.jsdelivr.net/npm/bootstrap-icons@1.7.2/font/bootstrap-icons.css");')
end

def add_simple_form
  generate "simple_form:install" 
  
  # Replace simple form initializer to work with layout
  run 'rm config/initializers/simple_form.rb'
  file 'config/initializers/simple_form.rb', <<~RUBY
  SimpleForm.setup do |config|
    # Wrappers configration
    config.wrappers :default, class: "form__group" do |b|
      b.use :html5
      b.use :placeholder
      b.use :label, class: "visually-hidden"
      b.use :input, class: "form__input", error_class: "form__input--invalid"
    end

    # Default configuration
    config.generate_additional_classes_for = []
    config.default_wrapper                 = :default
    config.button_class                    = "btn"
    config.label_text                      = lambda { |label, _, _| label }
    config.error_notification_tag          = :div
    config.error_notification_class        = "error_notification"
    config.browser_validations             = false
    config.boolean_style                   = :nested
    config.boolean_label_class             = "form__checkbox-label"
  end
  RUBY
end

def copy_templates
  run 'curl -L https://github.com/sschuez/rails-template/raw/main/stylesheets_bem.zip > stylesheets.zip'
  run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip'
  run 'mv app/assets/stylesheets/application.scss app/assets/stylesheets_bem'
  run 'rm -r app/assets/stylesheets'
  run 'mv app/assets/stylesheets_bem app/assets/stylesheets'
  run 'rm -r app/assets/__MACOSX'
end

def controllers
  # App controller
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
    #{  "protect_from_forgery with: :exception\n" if Rails.version < "5.2"}  before_action :authenticate_user!
    end
  RUBY

  # ApplicationHelper
  run 'rm app/helpers/application_helper.rb'
  file 'app/helpers/application_helper.rb', <<~RUBY
    module ApplicationHelper
      def render_turbo_stream_flash_messages
        turbo_stream.prepend "flash", partial: "shared/flash"
      end

      def form_error_notification(object)
        if object.errors.any?
          tag.div class: "error-message" do
            object.errors.full_messages.to_sentence.capitalize
          end
        end
      end

      def nested_dom_id(*args)
        args.map { |arg| arg.respond_to?(:to_key) ? dom_id(arg) : arg }.join("_")
      end
    end
  RUBY

  # Page controller
  generate(:controller, 'pages', 'home', '--skip-routes', '--no-test-framework')
  run 'rm app/controllers/pages_controller.rb'
  file 'app/controllers/pages_controller.rb', <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY
end

def set_environments
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

  gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')
end

def git_ignore
  append_file '.gitignore', <<~TXT
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT
end

def layouts
  # Meta
  style = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <script src="https://kit.fontawesome.com/649ff54fcc.js" crossorigin="anonymous"></script>
  HTML
  gsub_file('app/views/layouts/application.html.erb', '<meta name="viewport" content="width=device-width,initial-scale=1">', style)

  # Initial background-main
  background = <<~HTML
      <%= yield %>
        
      <%= render 'shared/footer' %>
  HTML
  gsub_file('app/views/layouts/application.html.erb', '<%= yield %>', background)
  
  # Flashes
  file 'app/views/shared/_flash.html.erb', <<~HTML
    <% flash.each do |flash_type, message| %>
      <div
        class="flash__message"
        data-controller="removals"
        data-action="animationend->removals#remove">
        <%= message %>
      </div>
    <% end %>

  HTML

  # Navbar
  file 'app/views/shared/_navbar.html.erb', <<~HTML
  <header class="navbar">
    <div class="navbar__brand">
      LOGO
    </div>
    <% if user_signed_in? %>
      <div class="navbar__name">
        <%= current_user.email %>
      </div>
      <%= button_to "Sign out",
                    destroy_user_session_path,
                    method: :delete,
                    class: "btn btn--secondary" %>
    <% else %>
      <%= link_to "Sign in",
                  new_user_session_path,
                  class: "btn btn--secondary navbar__right" %>
    <% end %>
  </header>

  HTML

  # Footer
  file 'app/views/shared/_footer.html.erb', <<~HTML
  <div class="footer">
    <div class="footer__links">
    </div>
    <div class="footer__copyright">
      Made with <i class="fas fa-heart"></i> by <a href="https://www.margareti.com" target="_blank">Margareti</a>
    </div>
  </div>

  HTML

  # Flash removals JS
  file 'app/javascript/controllers/removals_controller.js', <<~JS
  import { Controller } from "@hotwired/stimulus"

  // Connects to data-controller="removals"
  export default class extends Controller {
    remove() {
      this.element.remove()
    }
  }
  JS

  # Add to layout
  inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
  <<-HTML
  
    <%= render 'shared/navbar' %>

    <div id="flash" class="flash">
      <%= render "shared/flash" %>
    </div>
  HTML
  end
end

def set_up_rspec
  # Add binstubs
  run "./bin/bundle binstubs rspec-core"
  
  # Make all necesarry directories
  system 'mkdir', '-p', 'spec/support'
  system 'mkdir', '-p', 'spec/features'
  system 'mkdir', '-p', 'spec/factories'
  system 'mkdir', '-p', 'spec/policies'

  # Adjust rails_helper.rb
  gsub_file('spec/rails_helper.rb', "# Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }", "Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }")
  gsub_file('spec/rails_helper.rb', 'config.use_transactional_fixtures = true', 'config.use_transactional_fixtures = false')
  
  insert_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do
    <<-RUBY
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.extend ControllerMacros, type: :controller
    RUBY
  end
  
  # Adjust spec_helper.rb
  insert_into_file 'spec/spec_helper.rb', before: "RSpec.configure do |config|\n" do
    <<-RUBY
require 'pundit/matchers'
require 'capybara/rspec'
    RUBY
  end
  
  # Devise helpers
  file 'spec/support/controller_macros.rb', <<~RUBY
  module ControllerMacros
    def login_user
      # Before each test, create and login the user
      before(:each) do
        @request.env['devise.mapping'] = Devise.mappings[:user]
        sign_in FactoryBot.create(:user)
      end
    end
  end
  RUBY
  
  file 'spec/support/factory_bot.rb', <<~RUBY
  RSpec.configure do |config|
    config.include FactoryBot::Syntax::Methods
  end
  RUBY
  
  file 'spec/support/database_cleaner.rb', <<~RUBY
    RSpec.configure do |config|
      config.before(:suite) do
        DatabaseCleaner.clean_with(:truncation)
      end
      
      config.before(:each) do
        DatabaseCleaner.strategy = :transaction
      end
      
      config.before(:each, js: true) do
        DatabaseCleaner.strategy = :transaction
      end
      
      config.before(:each) do
        DatabaseCleaner.start
      end
      
      config.after(:each) do
        DatabaseCleaner.clean
      end
    end
  RUBY

  # First test
  file 'spec/features/user_visits_homepage_spec.rb', <<~RUBY
    require "rails_helper"
  
    feature "User visits homepage" do
      scenario "successfully" do
        visit root_path
        expect(page).to have_css 'h1', text: 'Pages#home'
      end
    end
  RUBY
end

# Main setup
add_gems

after_bundle do
  git_ignore
  add_users
  add_authorization
  add_dartsass_rails
  add_simple_form
  copy_templates
  controllers
  layouts
  set_environments
  rails_command 'db:drop db:create db:migrate'
  rails_command 'generate rspec:install'
  set_up_rspec
  
  # Commit everything to git
  unless ENV["SKIP_GIT"]
    git :init
    git add: "."
    begin
      git commit: %( -m 'Initial commit' )
    rescue StandardError => e
      puts e.message
    end
  end

  say
  say "Template app successfully created!", :blue
  say
  say "To run the server, run: bin/dev"
end
