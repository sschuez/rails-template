# Command
# rails new \
# --database postgresql \
# -m https://raw.githubusercontent.com/sschuez/rails-template/main/template.rb \
# CHANGE_THIS_TO_YOUR_RAILS_APP_NAME

run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

def rails_version
  @rails_version ||= Gem::Version.new(Rails::VERSION::STRING)
end

def rails_6_or_newer?
  Gem::Requirement.new(">= 6.0.0.alpha").satisfied_by? rails_version
end

def add_gems
  gem 'devise'
  gem 'pundit'
  gem "dartsass-rails"
  gem "bootstrap"
  gem 'simple_form'
  gem_group :development, :test do
    gem "rspec-rails"
  end
  gem_group :test do
    gem 'cucumber-rails', require: false
    gem 'database_cleaner'
  end
end

def add_users
  route "root to: 'pages#home'"
  generate "devise:install"
  generate "devise:views"

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

def add_sass
  rails_command "css:install:sass"
  run 'yarn build:css'
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
@use "components/error_message";
@use "components/flash";
@use "components/footer";
@use "components/navbar";
@use "components/sidebar";
@use "components/turbo_progress_bar";
@use "components/visually_hidden";

// Layouts
@use "layouts/container";
@use "layouts/header";

// Utilities
@use "utilities/margins";

// External Libraries
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
  
  # Replace simple form initializer to work with Bootstrap 5
  run 'curl -L https://raw.githubusercontent.com/heartcombo/simple_form-bootstrap/main/config/initializers/simple_form_bootstrap.rb > config/initializers/simple_form_bootstrap.rb'
  run 'rm config/initializers/simple_form.rb'
end

def copy_templates
  run 'curl -L https://github.com/sschuez/rails-template/raw/main/stylesheets_bootstrap.zip > stylesheets.zip'
  run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip'
  run 'mv app/assets/stylesheets/application.scss app/assets/stylesheets_bootstrap'
  run 'rm -r app/assets/stylesheets'
  run 'mv app/assets/stylesheets_bootstrap app/assets/stylesheets'
  # run 'rm -r app/assets/__MACOSX'
end

unless rails_6_or_newer?
  puts "Please use Rails 6.0 or newer to create an application with this template"
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
        sign_out: '<i class="bi bi-box-arrow-in-right"></i>',
        sign_in: '<i class="bi bi-box-arrow-right"></i>',
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
  <div  class="sidebar" 
        data-sidebar-target="toggle" data-action="click->sidebar#toggleClose">
    <div class="sidebar__container">
      <div class="sidebar__inner">
        <div class="sidebar__context">
        
          <button id="close-button" data-action="click->sidebar#toggleClose">
            <%= Icon.new("close_lg").call %>
          </button>
        
          <ul data-controller="sidebar">
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
    <div class="footer__links">
      <a href="#"><i class="fab fa-instagram"></i></a>
      <a href="#"><i class="fab fa-linkedin"></i></a>
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
  rails_command 'generate cucumber:install'
  
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
