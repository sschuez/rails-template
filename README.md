# Start Rails App with Users
Project with devise, user model (email, admin:boolean) and bootstrap preconfigured.
```bash
rails new \
--database postgresql \
-m https://raw.githubusercontent.com/sschuez/rails-template/main/devise.rb \
CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```

# Gems that are installed and configured:
* devise (Authetication)
* pundit (Authorisation)
* cssbundling-rails (Bundling Sass & Bootstrap)
* simple_form (preconfigured with Bootstrap)

# Layouts
I added a navbar, a footer and some alerts. Fontawesome is shipped, too. You can easily add dark-mode.
The whole css is done via cssbundling:sass. I have created an easy structure to organise the sass-stylesheets under your assets: 
* components 
* pages
* config (for your fonts and global variables)

# Javascript
The Javascript is handled via importmaps, the default route of Rails 7.

# Setup
The template will run db:create db:migrate and the it will run yarn build:css. So running bin/dev should be enough for you to get going.
A .gitignore setup is also provided.
