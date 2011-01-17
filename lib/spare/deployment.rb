class Spare::Deployment

  def self.define_task(context, task_method = :task, opts = {})
    if defined?(Capistrano) && context.is_a?(Capistrano::Configuration)
      context_name = "capistrano"
      role_default = "{:except => {:no_release => true}}"
    else
      context_name = "vlad"
      role_default = "[:app]"
    end

    roles = context.fetch(:backup_roles, false)
    opts[:roles] = roles if roles

    context.send :namespace, :backup do

      send :desc, <<-DESC
        Pull and restore a backup from the backup respository.

        You can override any of these defaults by setting the variables shown below.

        N.B. backup_roles must be defined before you require 'spare/#{context_name}' \
        in your deploy.rb file.

          set :spare_pull_task, "backup:pull"
          set :spare_pull_ref,  ENV['REF']
          set :rake_cmd,        "rake" # e.g. "/opt/ruby/bin/rake"
          set :backup_roles,    #{role_default} # e.g. [:app, :batch]
      DESC
      send task_method, :pull, opts do
        rake_cmd  = context.fetch(:rake_cmd,        "rake")
        rake_task = context.fetch(:spare_pull_task, "backup:pull")
        ref       = context.fetch(:spare_pull_ref,  ENV['REF'])

        unless ref or ref.strip.empty?
          raise "Please provide a REF argument: REF=<ref>"
        end

        run "#{rake_cmd} #{rake_task} REF=#{ref}"
      end

      send :desc, <<-DESC
        Push a new backup to the backup respository.

        You can override any of these defaults by setting the variables shown below.

        N.B. backup_roles must be defined before you require 'spare/#{context_name}' \
        in your deploy.rb file.

          set :spare_push_task, "backup:push"
          set :rake_cmd,        "rake" # e.g. "/opt/ruby/bin/rake"
          set :backup_roles,    #{role_default} # e.g. [:app, :batch]
      DESC
      send task_method, :push, opts do
        rake_cmd  = context.fetch(:rake_cmd,        "rake")
        rake_task = context.fetch(:spare_push_task, "backup:push")

        run "#{rake_cmd} #{rake_task}"
      end

    end
  end

end