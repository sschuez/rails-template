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
@use "config/animations";

// Components
@use "components/error_message";
@use "components/flash";
@use "components/footer";
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
  
  <nav class="navbar navbar-expand-lg navbar-light bg-light">
    <a class="navbar-brand" href="#">Navbar</a>
    <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarNav">
      <ul class="navbar-nav">
        <li class="nav-item active">
          <a class="nav-link" href="#">Home <span class="sr-only">(current)</span></a>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="#">Features</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="#">Pricing</a>
        </li>
        <li class="nav-item">
          <a class="nav-link disabled" href="#">Disabled</a>
        </li>
      </ul>
    </div>
  </nav>

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
