# Vlad task for Spare.
#
# Just add "require 'spare/vlad'" in your Vlad deploy.rb, and
# include the vlad:backup:push task in your vlad:deploy task.
require 'spare/deployment'

namespace :vlad do
  Spare::Deployment.define_task(Rake::RemoteTask, :remote_task, :roles => :app)
end