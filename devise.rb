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

  # environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'development'
  # environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

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
#   run "yarn add local-time esbuild-rails trix @hotwired/stimulus @hotwired/turbo-rails @rails/activestorage @rails/ujs @rails/request.js"
# end

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


unless rails_6_or_newer?
  puts "Please use Rails 6.0 or newer to create a Jumpstart application"
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
  style = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  HTML
  
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
                  <%= link_to "Log out", destroy_user_session_path, method: :delete, class: "dropdown-item" %>
                </div>
              </li>
            <% else %>
              <li class="nav-item">
                <%= link_to "Login", new_user_session_path, class: "nav-link" %>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>

  HTML

  # Add to layout
  inject_into_file 'app/views/layouts/application.html.erb', after: '<body>' do
    <<-HTML
  
      <%= render 'shared/navbar' %>
      <%= render 'shared/flashes' %>
    HTML
  end
end

# Main setup
add_gems

after_bundle do
  add_users
  add_authorization
  # add_jsbundling
  # add_javascript
  
  add_sass
  copy_templates
  add_simple_form
  controllers
  set_environments
  layouts
  
  rails_command "active_storage:install"

  rails_command 'db:migrate'
  
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
