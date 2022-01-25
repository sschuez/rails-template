# Command
# rails new \
# --database postgresql \
# -m https://github.com/sschuez/rails-template/blob/main/devise.rb \
# CHANGE_THIS_TO_YOUR_RAILS_APP_NAME

gem 'devise'

run bundle 'install'

generate(:scaffold, 'user', 'admin:boolean')

rails_command('generate devise:install')
rails_command('generate devise User')

#Test