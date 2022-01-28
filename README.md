# Start with User

Project with devise, user model (email, admin:boolean) and bootstrap preconfigured. I also added a navbar, a footer and some alerts.

```bash
rails new \
--database postgresql \
-m https://raw.githubusercontent.com/sschuez/rails-template/main/devise.rb \
CHANGE_THIS_TO_YOUR_RAILS_APP_NAME
```

The template will run db:create db:migrate and the it will run yarn build:css. So running bin/dev should be enough for you to get going.