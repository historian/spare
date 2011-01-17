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
        
      DESC
      send task_method, :pull, opts do
        rake_cmd    = context.fetch(:rake_cmd, "rake")
        rake_task   = context.fetch(:spare_pull_task, "--deployment --quiet")
        bundle_dir     = context.fetch(:bundle_dir, File.join(context.fetch(:shared_path), 'bundle'))
        bundle_gemfile = context.fetch(:bundle_gemfile, "Gemfile")
        bundle_without = [*context.fetch(:bundle_without, [:development, :test])].compact
  
        args = ["--gemfile #{File.join(context.fetch(:current_release), bundle_gemfile)}"]
        args << "--path #{bundle_dir}" unless bundle_dir.to_s.empty?
        args << bundle_flags.to_s
        args << "--without #{bundle_without.join(" ")}" unless bundle_without.empty?
  
        run "#{rake_cmd} #{rake_task} #{args.join(' ')}"
      end

      send :desc, <<-DESC
        
      DESC
      send task_method, :push, opts do
        bundle_cmd     = context.fetch(:bundle_cmd, "bundle")
        bundle_flags   = context.fetch(:bundle_flags, "--deployment --quiet")
        bundle_dir     = context.fetch(:bundle_dir, File.join(context.fetch(:shared_path), 'bundle'))
        bundle_gemfile = context.fetch(:bundle_gemfile, "Gemfile")
        bundle_without = [*context.fetch(:bundle_without, [:development, :test])].compact
  
        args = ["--gemfile #{File.join(context.fetch(:current_release), bundle_gemfile)}"]
        args << "--path #{bundle_dir}" unless bundle_dir.to_s.empty?
        args << bundle_flags.to_s
        args << "--without #{bundle_without.join(" ")}" unless bundle_without.empty?
  
        run "#{bundle_cmd} install #{args.join(' ')}"
      end

    end
  end
  
end