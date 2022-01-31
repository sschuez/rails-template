# Command
# rails new \
# --database postgresql \
# -m https://raw.githubusercontent.com/sschuez/rails-template/main/devise.rb \
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
  gem 'cssbundling-rails'
#   gem 'jsbundling-rails'
  gem 'simple_form'
  # gem 'pry-byebug'
  # gem 'pry-rails'
  # gem 'dotenv-rails'
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

# def add_jsbundling
#   rails_command "javascript:install:esbuild"
# end

# def add_javascript
#   run "yarn add esbuild-rails trix @hotwired/stimulus @hotwired/turbo-rails @rails/activestorage @rails/ujs @rails/request.js"
# end

def add_bootstrap
  rails_command "css:install:bootstrap"
  
  rails_command "simple_form:install"
  # rails_command "simple_form:install --bootstrap"
 
  # generate "simple_form:install --bootstrap"

  # Replace simple form initializer to work with Bootstrap 5
  run 'curl -L https://raw.githubusercontent.com/heartcombo/simple_form-bootstrap/main/config/initializers/simple_form_bootstrap.rb > config/initializers/simple_form_bootstrap.rb'

  run "rm app/assets/stylesheets/application.bootstrap.scss"

  run "bin/importmap pin bootstrap"
end

def add_sass
  rails_command "css:install:sass"
  run 'yarn build:css'
end

def copy_templates
  run 'curl -L https://github.com/sschuez/rails-template/raw/main/stylesheets.zip > stylesheets.zip'
  run 'rm app/assets/stylesheets/application.sass.scss'
  run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip'
  run 'rm -r app/assets/__MACOSX'
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
      
      <div class="background-main">
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
          <%= image_tag "https://raw.githubusercontent.com/lewagon/fullstack-images/master/uikit/logo.png" %>
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
  <div class="dark-mode-switch" data-controller="dark">
    <div class=dark-mode-btn data-action="click->dark#darkMode">
    </div>
  </div>

  HTML
  
  # Dark Model JS
  file 'app/javascript/controllers/dark_controller.js', <<~JS
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    connect() {
      var theme = getCookie("theme")
      if (theme == "light-mode") {
        document.querySelector(".dark-mode-btn").innerHTML = "🌘"
      } else {
        document.querySelector(".dark-mode-btn").innerHTML = "🌞"
      }

      // Get cookie - for reference only (cosole.log())
      function getCookie(cname) {
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
  
    darkMode() {
      var element = document.body
      element.classList.toggle("dark-mode")
  
      // Cookies toggle
      let currentTheme = element.classList.contains("dark-mode") ? "dark-mode" : "light-mode"
      if (currentTheme == "dark-mode") {
        document.body.classList.remove("light-mode")
        document.querySelector(".dark-mode-btn").innerHTML = "🌞"
        document.cookie = "theme=dark-mode"
      } else {
        document.cookie = "theme=light-mode"
        document.querySelector(".dark-mode-btn").innerHTML = "🌘"
      }
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

# def add_esbuild_script
#   build_script = "node esbuild.config.js"

#   if (`npx -v`.to_f < 7.1 rescue "Missing")
#     say %(Add "scripts": { "build": "#{build_script}" } to your package.json), :green
#   else
#     run %(npm set-script build "#{build_script}")
#   end
# end

# Main setup
add_gems

after_bundle do
  git_ignore

  add_users
  add_authorization
  
  # add_jsbundling
  # add_javascript
  
  add_bootstrap
  add_sass
  copy_templates
  
  
  controllers
  layouts
  
  set_environments
  # add_esbuild_script

  rails_command "active_storage:install"
  rails_command 'db:drop db:create db:migrate'
  run "yarn build:css"
  
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
