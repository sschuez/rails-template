# Command
# rails new \
# --database postgresql \
# -m https://raw.githubusercontent.com/sschuez/rails-template/main/template.rb \
# CHANGE_THIS_TO_YOUR_RAILS_APP_NAME

def add_gems
  gem 'devise'
  gem 'pundit'
  gem "dartsass-rails"
  gem "bootstrap"
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

  if Gem::Requirement.new("> 5.2").satisfied_by? rails_version
    gsub_file "config/initializers/devise.rb", /  # config.secret_key = .+/, "  config.secret_key = Rails.application.credentials.secret_key_base"
  end
end

def add_authorization
  generate 'pundit:install'
end

# def add_jsbundling
#   rails_command "javascript:install:esbuild"
# end

# def add_javascript
#   run "yarn add esbuild-rails trix @hotwired/stimulus @hotwired/turbo-rails @rails/activestorage @rails/ujs @rails/request.js"
# end

# def add_sass
#   rails_command "css:install:sass"
#   run 'yarn build:css'
# end

def add_dartsass_rails
  run "./bin/bundle add dartsass-rails"
  run "./bin/rails dartsass:install"  
  run "rm app/assets/stylesheets/application.css"
  gsub_file('app/assets/stylesheets/application.scss', '// Sassy', '@use "components/index_components";
@use "pages/index_pages";

// External libraries
@import "bootstrap";
@import url("https://cdn.jsdelivr.net/npm/bootstrap-icons@1.7.2/font/bootstrap-icons.css");')
end

def add_bootstrap
  run "bin/importmap pin bootstrap"
  gsub_file('app/javascript/application.js', 'import "controllers"', 'import "controllers"
import "bootstrap"')
end


def add_simple_form
  generate "simple_form:install --bootstrap" 
end

def copy_templates
  run 'curl -L https://github.com/sschuez/rails-template/raw/main/stylesheets.zip > stylesheets.zip'
  run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip'
  # run 'rm -r app/assets/__MACOSX'
end

def controllers
  # # App controller
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
    #{  "protect_from_forgery with: :exception\n" if Rails.version < "5.2"}  before_action :authenticate_user!
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

  # Errors controller
  run 'rm public/500.html'
  run 'rm public/404.html'

  route "match '/500', via: :all, to: 'errors#internal_server_error'"
  route "match '/404', via: :all, to: 'errors#not_found'"

  application 'config.exceptions_app = self.routes'

  file 'app/controllers/errors_controller.rb', <<~RUBY
    class ErrorsController < ActionController::Base

      def internal_server_error
        render status: 500
      end
    
      def not_found
        render status: 404
      end
    end
  RUBY
  
  file 'app/views/layouts/errors.html.erb', <<~HTML
    <!DOCTYPE html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
        <script src="https://kit.fontawesome.com/649ff54fcc.js" crossorigin="anonymous"></script>

        <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
        <%= javascript_importmap_tags %>
      </head>

      <body class="text-center">

        <div id="flash" class="flash">
          <%= render "shared/flash" %>
        </div>

        <div class="container">
          <%= yield %>
        </div>

      </body>
    </html>
  HTML
  
  file 'app/views/errors/internal_server_error.html.erb', <<~HTML
    <h1>😱 <%= response.status %> <%= action_name.humanize %> 😱</h1>
    <br>
    <p>Really sorry, something went wrong here 😅</p>
    <br>
    <%= link_to "Back to homepage", root_url %>
  HTML

  file 'app/views/errors/not_found.html.erb', <<~HTML
    <h1>😱 <%= response.status %> <%= action_name.humanize %> 😱</h1>
    <br>
    <p>Sorry, this page does not exist 😅</p>
    <br>
    <%= link_to "Back to homepage", root_url %>
  HTML

  
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
      
      <div class="container">
        <%= yield %>
      </div>    
      <%= render 'shared/footer' %>
  HTML
  gsub_file('app/views/layouts/application.html.erb', '<%= yield %>', background)
  
  # Flashes
  file 'app/views/shared/_flashes.html.erb', <<~HTML
    <% if notice %>
      <div class="alert alert-info alert-dismissible fade show m-1" role="alert">
        <%= notice %>
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
        </button>
      </div>
    <% end %>
    <% if alert %>
      <div class="alert alert-warning alert-dismissible fade show m-1" role="alert">
        <%= alert %>
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
        </button>
      </div>
    <% end %>
  HTML

  # Navbar
  file 'app/views/shared/_navbar.html.erb', <<~HTML
  
    <div class="navbar navbar-expand-sm navbar-light navbar-lewagon">
      <div class="container-fluid">
        <%= link_to "#", class: "navbar-brand" do %>
          <h4>Logo</h4>
        <% end %> 

        <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
          <span class="navbar-toggler-icon"></span>
        </button>

        <div class="collapse navbar-collapse" id="navbarSupportedContent">
          <ul class="navbar-nav me-auto">
            <% if user_signed_in? %>
              <li class="nav-item active">
                <%= link_to "Home", "#", class: "nav-link" %>
              </li>
              <li class="nav-item">
                <%= link_to "Messages", "#", class: "nav-link" %>
              </li>
              <li class="nav-item dropdown">
                <%= image_tag "https://kitt.lewagon.com/placeholder/users/sschuez", class: "avatar dropdown-toggle", id: "navbarDropdown", data: { bs_toggle: "dropdown" }, 'aria-haspopup': true, 'aria-expanded': false %>
                <div class="dropdown-menu dropdown-menu-end" aria-labelledby="navbarDropdown">
                  <%= link_to "Action", "#", class: "dropdown-item" %>
                  <%= link_to "Another action", "#", class: "dropdown-item" %>
                  <%= link_to "Log out", destroy_user_session_path, 'data-turbo-method': :delete, class: "dropdown-item" %>
                </div>
              </li>
              <li class="nav-item">
                <%= render "shared/dark_mode" %>
              </li>
            <% else %>
              <li class="nav-item">
                <%= link_to "Login", new_user_session_path, class: "nav-link" %>
              </li>
              <li class="nav-item">
                <%= render "shared/dark_mode" %>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>

  HTML

  # Footer
  file 'app/views/shared/_footer.html.erb', <<~HTML
    <div class="footer">
      <div class="footer-links">
        <a href="#"><i class="fab fa-github"></i></a>
        <a href="#"><i class="fab fa-instagram"></i></a>
        <a href="#"><i class="fab fa-facebook"></i></a>
        <a href="#"><i class="fab fa-twitter"></i></a>
        <a href="#"><i class="fab fa-linkedin"></i></a>
      </div>
      <div class="footer-copyright">
        This footer is made with <i class="fas fa-heart"></i> by <a href="https://www.margareti.com" target="_blank">Margareti</a>
      </div>
    </div>
  HTML

  # Dark Mode HTML
  file 'app/views/shared/_dark_mode.html.erb', <<~HTML
  <div class="dark-mode-switch" data-controller="dark" data-action="click->dark#darkMode">
  </div>

  HTML
  
  # Dark Model JS
  file 'app/javascript/controllers/dark_controller.js', <<~JS
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    connect() {
      if (this.getCookie("theme") == "light-mode") {
        this.element.innerHTML = "🌘"
      } else {
        this.element.innerHTML = "🌞"
      }
    }
  
    darkMode() {
      document.body.classList.toggle("dark-mode")
    
      // Cookies toggle
      let currentTheme = document.body.classList.contains("dark-mode") ? "dark-mode" : "light-mode"
      if (currentTheme == "dark-mode") {
        document.body.classList.remove("light-mode")
        this.element.innerHTML = "🌞"
        document.cookie = "theme=dark-mode"
      } else {
        document.cookie = "theme=light-mode"
        this.element.innerHTML = "🌘"
      }
    }

    // Get cookie - for reference only (cosole.log())
    getCookie(cname) {
      let name = cname + "=";
      let ca = document.cookie.split(';');
      for(let i = 0; i < ca.length; i++) {
        let c = ca[i];
        while (c.charAt(0) == ' ') {
          c = c.substring(1);
        }
        if (c.indexOf(name) == 0) {
          return c.substring(name.length, c.length);
        }
      }
      return "";
    }
  }
  JS

  # Add to layout
  inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
  <<-HTML
  
  <%= render 'shared/navbar' %>
  <%= render 'shared/flashes' %>
  HTML
  end

  # Add dark-mode to body -> needs to be at the end!
  gsub_file('app/views/layouts/application.html.erb', '<body>', '<body class="<%= cookies[:theme] %>">')

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
  
  # add_jsbundling
  # add_javascript
  add_dartsass_rails
  add_bootstrap
  # add_sass
  add_simple_form
  copy_templates
  
  
  controllers
  layouts
  
  set_environments

  rails_command 'db:drop db:create db:migrate'
  # run "yarn build:css"
  rails_command 'generate rspec:install'
  set_up_rspec
  
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

  say
  say "Template app successfully created!", :blue
  say
  # say "You still have to run:  rails db:create db:migrate"
  # say "And then to build the css: yarn build:css"  
  say "To run the server, run: bin/dev"
end
