# Start Rails App with Users
Project with devise, user model (email, admin:boolean) and bootstrap preconfigured.
```bash
rails new \
--database postgresql \
-m https://raw.githubusercontent.com/sschuez/rails-template/main/template.rb \
CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```

or

```bash
rails new \
--database postgresql \
-m https://raw.githubusercontent.com/sschuez/rails-template/main/template_bem.rb \
CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```


# Gems that are installed and configured:
* devise (Authetication)
* pundit (Authorisation)
* dartsass-rails for stylesheets (with Bootstrap)
* simple_form (preconfigured with Bootstrap)

# Layouts
I added a navbar, a footer and some alerts. Fontawesome, as well as bootstrap is configured for icons.
The whole css is done via dartsass-rails. I have created a structure to organise the sass-stylesheets under your assets: 
* components 
* pages
* config (for your fonts and global variables)

# Dark Mode
I implemented a basic dark mode functionality, with a shared/dark_mode button preconfigured in the navbar. CSS class is stored in cookies via stimulus controller.

# Javascript
The Javascript is handled via importmaps, the default in of Rails 7.

# Setup
The template will run db:create db:migrate and the it will run yarn build:css. So running bin/dev should be enough for you to get going.
A .gitignore setup is also provided.
