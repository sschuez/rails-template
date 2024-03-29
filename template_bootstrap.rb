# Command
# rails new \
# --database postgresql \
# -a propshaft \
# -m https://raw.githubusercontent.com/sschuez/rails-template/main/template.rb \
# CHANGE_THIS_TO_YOUR_RAILS_APP_NAME

def add_gems
  gem 'devise'
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
  run "./bin/bundle add dartsass-rails"
  run "./bin/rails dartsass:install"  
  run "rm app/assets/stylesheets/application.css"
  gsub_file('app/assets/stylesheets/application.scss', '// Sassy', '// Mixins
@use "mixins/media";

// Configuration
@use "config/variables";
@use "config/reset";
@use "config/animations";

// Components
@use "components/btn";
@use "components/error_message";
@use "components/flash";
@use "components/footer";
@use "components/navbar";
@use "components/sidebar";
@use "components/turbo_progress_bar";
@use "components/visually_hidden";

// Layouts
@use "layouts/bootstrap";
@use "layouts/container";
@use "layouts/header";

// Utilities
@use "utilities/margins";

// External Libraries
// @import url("https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css");
@import url("https://cdn.jsdelivr.net/npm/bootstrap-icons@1.7.2/font/bootstrap-icons.css");')
end

def add_bootstrap
  run "bin/importmap pin bootstrap"
  gsub_file('app/javascript/application.js', 'import "controllers"', 'import "controllers"
import "bootstrap"')
end

def add_simple_form
  generate "simple_form:install --bootstrap" 
  
  # Replace simple form initializer to work with Bootstrap 5
  # run 'curl -L https://raw.githubusercontent.com/heartcombo/simple_form-bootstrap/main/config/initializers/simple_form_bootstrap.rb > config/initializers/simple_form_bootstrap.rb'
  # run 'rm config/initializers/simple_form.rb'
end

def copy_templates
  run 'curl -L https://github.com/sschuez/rails-template/raw/main/stylesheets_bootstrap.zip > stylesheets.zip'
  run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip'
  run 'mv app/assets/stylesheets/application.scss app/assets/stylesheets_bootstrap'
  run 'rm -r app/assets/stylesheets'
  run 'mv app/assets/stylesheets_bootstrap app/assets/stylesheets'
  # run 'rm -r app/assets/__MACOSX'
end

def controllers
  # App controller
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
    #{  "protect_from_forgery with: :exception\n" if Rails.version < "5.2"}  before_action :authenticate_user!
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
    <%= link_to "Back to homepage", root_url, class: "my-btn my-btn--primary" %>
  HTML

  file 'app/views/errors/not_found.html.erb', <<~HTML
    <h1>😱 <%= response.status %> <%= action_name.humanize %> 😱</h1>
    <br>
    <p>Sorry, this page does not exist 😅</p>
    <br>
    <%= link_to "Back to homepage", root_url, class: "my-btn my-btn--primary" %>
  HTML


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
  # Icons
  file 'app/models/concerns/icon.rb', <<~RUBY
  class Icon
    def initialize(icon)
      @icon = icon
      @icons = {
        trash: '<i class="bi bi-trash-fill"></i>',
        edit: '<i class="bi bi-pencil-fill"></i>',
        confirm: '<i class="bi bi-check-circle-fill"></i>',
        cancel: '<i class="bi bi-x-circle-fill"></i>',
        handle: '<i class="bi bi-grip-horizontal handle mt-xxs ml-s"></i>',
        repeat: '<i class="bi bi-arrow-repeat"></i>',
        hamburger: '<i class="bi bi-list hamburger"></i>',
        close: '<i class="bi bi-x"></i>',
        close_lg: '<i class="bi bi-x-lg"></i>',
        sign_out: '<i class="bi bi-box-arrow-right"></i>',
        sign_in: '<i class="bi bi-box-arrow-in-right"></i>',
        translate: '<i class="bi bi-translate"></i>'
      }
    end
  
    def call
      @icons[@icon.to_sym].html_safe
    end
  end
  RUBY

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
  
  # Navbar JS
  file 'app/javascript/controllers/navbar_controller.js', <<~JS
  import { Controller } from "@hotwired/stimulus"

  // Connects to data-controller="navbar"
  export default class extends Controller {
    updateNavbar() {
      if (window.scrollY >= window.innerHeight) {
        this.element.classList.add("navbar--white")
      } else {
        this.element.classList.remove("navbar--white")
      }
    }
  }
  JS

  # Navbar HTML
  file 'app/views/shared/_navbar.html.erb', <<~HTML
  <header class="navbar fixed-top" 
          data-controller="sidebar navbar"
          data-action="scroll@window->navbar#updateNavbar">
    <div class="navbar__brand">
      <%= link_to "LOGO", root_path %>
    </div>
    <% if user_signed_in? %>
      <div class="navbar__name">
        <%= current_user.email %>
      </div>
    <% end %>
    <button data-action="click->sidebar#toggleOpen">
      <%= Icon.new("hamburger").call %>
    </button>
    <%= render partial: "shared/sidebar" %>
  </header>
  HTML

  #  Sidebar JS
  file 'app/javascript/controllers/sidebar_controller.js', <<~JS
  import { Controller } from "@hotwired/stimulus"

  // Connects to data-controller="sidebar"
  export default class extends Controller {
    static targets = [ "toggle", "sub", "arrowIcon" ]

    connect() {
      this.arrowDown = `<i class="bi bi-caret-down-fill" id="caret"></i>`
      this.arrowLeft = `<i class="bi bi-caret-left-fill" id="caret"></i>`
    
      this.getArrowIcons()
    }

    getArrowIcons() {
      this.arrowIconTargets.forEach(arrow => {
        arrow.insertAdjacentHTML("beforebegin", this.arrowDown)
        arrow.remove()
      })
    }

    toggleOpen() {
      this.toggleTarget.classList.add("open");
    }
  
    toggleClose() {
      if (event.target.classList.contains("sidebar") || event.currentTarget.id === "close-button") {
        this.toggleTarget.classList.remove("open");
      }
    }
  
    toggleSub() {
      const sub = event.currentTarget.querySelector("#sub")
      const arrow = event.currentTarget.querySelector("#caret")

      sub.classList.toggle("open")    
    
      if (sub.classList.contains("open")) {
        arrow.insertAdjacentHTML("beforebegin", this.arrowLeft)
        arrow.remove()
      } else {
        arrow.insertAdjacentHTML("beforebegin", this.arrowDown)
        arrow.remove()
      }
    }
  }
  JS

  # Sidebar HTML
  file 'app/views/shared/_sidebar.html.erb', <<~HTML
  <div class="sidebar" 
        data-sidebar-target="toggle" data-action="click->sidebar#toggleClose">
    <div class="sidebar__container">
      <div class="sidebar__inner">
        <div class="sidebar__context">
      
          <button id="close-button" data-action="click->sidebar#toggleClose">
            <%= Icon.new("close_lg").call %>
          </button>
      
          <ul>
            <% if user_signed_in? %>
              <li>
                <%= button_to destroy_user_session_path,
                    method: :delete,
                    class: "sidebar__item" do %>
                  <%= Icon.new("sign_out").call %>
                  <span>Sign out</span>
                <% end %>
              </li>
            <% else %>
              <li>
                <%= link_to new_user_session_path, class: "sidebar__item" do %>
                  <%= Icon.new("sign_in").call %>
                  <span>Sign in</span>
                <% end %>
              </li>
            <% end %>

            <li>
              <div class="divider"></div>
            </li>

            <li>
              <%= link_to root_path, class: "sidebar__item" do %>
                <%= Icon.new("repeat").call %>
                <span>
                  Another button
                </span>
              <% end %>
            </li>
          
            <li>
              <div class="divider"></div>
            </li>
        
            <li>
              <%= link_to root_path, class: "sidebar__item" do %>
                <%= Icon.new("repeat").call %>
                <span>
                  One more button
                </span>
              <% end %>
            </li>

            <li>
              <button class="sidebar__item toggle" data-action="click->sidebar#toggleSub">
                <%= Icon.new("translate").call %>
                <span>
                  Language
                </span>
                <div data-sidebar-target="arrowIcon"></div>
                <div class="toggle-sub" id="sub">
                  <ul>
                    <li>
                      <%= link_to 'One language', url_for(locale: :de) %>
                    </li>
                    <li>
                      <%= link_to 'Another language', url_for(locale: :en) %>
                    </li>
                  </ul>
                </div>
              </button>
            </li>

            <li>
              <button class="sidebar__item toggle" data-action="click->sidebar#toggleSub">
                <%= Icon.new("repeat").call %>
                <span>
                  Something else
                </span>
                <div data-sidebar-target="arrowIcon"></div>
                <div class="toggle-sub" id="sub">
                  <ul>
                    <li>
                      <%= link_to 'Root', root_path %>
                    </li>
                    <li>
                      <%= link_to 'Root 2', root_path %>
                    </li>
                  </ul>
                </div>
              </button>
            </li>

          </ul>

        </div>
      </div>
    </div>
  </div>
  HTML

  # Footer
  file 'app/views/shared/_footer.html.erb', <<~HTML
  
  <div class="footer">
    <div class="container">
      <footer class="py-5">
        <div class="row">
          <div class="col-6 col-md-2 mb-3">
            <h5>Section</h5>
            <ul class="nav flex-column">
              <li class="nav-item mb-2">
                <%= link_to "A link", root_path, class: "nav-link p-0 text-muted" %>
              </li>
              <li class="nav-item mb-2">
              <%= link_to "A link", root_path, class: "nav-link p-0 text-muted" %>
              </li>
              <li class="nav-item mb-2">
              <%= link_to "A link", root_path, class: "nav-link p-0 text-muted" %>
              </li>
            </ul>
          </div>

          <div class="col-6 col-md-2 mb-3">
            <h5>Section</h5>
            <ul class="nav flex-column">
              <li class="nav-item mb-2">
              <%= link_to "A link", root_path, class: "nav-link p-0 text-muted" %>
              </li>
              <li class="nav-item mb-2">
              <%= link_to "A link", root_path, class: "nav-link p-0 text-muted" %>
              </li>
              <li class="nav-item mb-2">
              <%= link_to "A link", root_path, class: "nav-link p-0 text-muted" %>
              </li>
            </ul>
          </div>

          <div class="col-6 col-md-2 mb-3">
            <h5>Section</h5>
            <ul class="nav flex-column">
              <li class="nav-item mb-2">
                <%= link_to "A link", root_path, class: "nav-link p-0 text-muted" %>
              </li>
              <li class="nav-item mb-2">
                <%= link_to "A link", root_path, class: "nav-link p-0 text-muted" %>
              </li>
              <% if user_signed_in? %>
                <li class="nav-item mb-2">
                  <%= button_to "Log out",
                      destroy_user_session_path,
                      method: :delete,
                      class: "nav-link p-0 text-muted button" %>
                </li>
              <% else %>
                <li class="nav-item mb-2">
                  <%= link_to "Log in",
                      new_user_session_path, 
                      class: "nav-link p-0 text-muted" %>
                </li>
              <% end %>
            </ul>
          </div>

          <%# <div class="col-md-5 offset-md-1 mb-3"> %>
            <%#= form_tag adduser_path, method: :post, data: { turbo: false } do %>
            <%#= form_tag root_path, method: :post, data: { turbo: false } do %>
              <%# <h5>Subscribe to the newsletter</h5> %>
              <%# <p>Digest of what's new and exciting.</p> %>
              <%# <div class="d-flex flex-column flex-sm-row w-100 gap-2"> %>
                <%# <label for="newsletter1" class="visually-hidden">Email address</label> %>
                  <%# <input id="newsletter1" name="email_address" type="text" class="form-control" placeholder="Email address"> %>
                  <%# <input type="submit" value="💌 Subscribe" class="my-btn my-btn--dark"> %>
              <%# </div> %>
            <%# end %>
          <%# </div> %>
        </div>

        <div class="d-flex flex-column flex-sm-row justify-content-between py-4 my-4 border-top">
          <p class="footer__copyright"> 
            Made with ♥️ by &copy; <a href="https://www.margareti.com" target="_blank">Margareti</a>
          </p>
          <ul class="list-unstyled d-flex">
            <li class="ms-3"><a class="link-dark" href="#"><svg class="bi" width="24" height="24"><use xlink:href="#twitter"></use></svg></a></li>
            <li class="ms-3"><a class="link-dark" href="#"><svg class="bi" width="24" height="24"><use xlink:href="#instagram"></use></svg></a></li>
            <li class="ms-3"><a class="link-dark" href="#"><svg class="bi" width="24" height="24"><use xlink:href="#facebook"></use></svg></a></li>
          </ul>
        </div>
      </footer>
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
  add_bootstrap
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
