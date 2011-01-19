# Capistrano task for Spare.
#
# Just add "require 'spare/capistrano'" in your Capistrano deploy.rb, and
# Spare will be activated after each new deployment.
require 'spare/deployment'

Capistrano::Configuration.instance(:must_exist).load do
  before "deploy:update_code",     "backup:create_with_rollback"
  after  "deploy:finalize_update", "backup:link_repository"
  Spare::Deployment.define_task(self, :task, :except => { :no_release => true })
end