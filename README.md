# Start with User

Project with devise, user model (email, admin:boolean):

```bash
rails new \
--database postgresql \
-m https://raw.githubusercontent.com/sschuez/rails-template/main/devise.rb \
CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```

After you have db:migrated the app, run bin/dev to build the stylesheet.css from application.sass.scss. As a little workarount for the bootstrap integration, you need to comment out the @use 'bootstrap' line, save, and then uncomment it again, while bin/dev runs. This will compile both sass and bootstrap at once.