class Spare::Task

  def initialize(base_name, &block)
    @base_name = base_name

    if Rake.application.current_scope.empty?
      Rake.application.in_namespace 'backup' do
        install_master_tasks
        instance_eval(&block) if block
      end
    else
      install_master_tasks
      instance_eval(&block) if block
    end
  end

  def before_backup(*args, &block)
    task = Rake::Task.define_task(*args, &block)
    Rake::Task.define_task("before_push" => task.name)
    task
  end

  def backup(&block)
    task = Spare::BackupTask.define_task("#{@base_name}:backup", &block)
    @config.backup_tasks[task.name] = task
    Rake::Task.define_task("checkin_backup" => task.name)
    task
  end

  def after_backup(*args, &block)
    task = Rake::Task.define_task(*args, &block)
    Rake::Task.define_task("after_push" => task.name)
    task
  end

  def before_restore(*args, &block)
    task = Rake::Task.define_task(*args, &block)
    Rake::Task.define_task("before_pull" => task.name)
    task
  end

  def restore(&block)
    task = Spare::RestoreTask.define_task("#{@base_name}:restore", &block)
    @config.restore_tasks[task.name] = task
    Rake::Task.define_task("checkout_restore" => task.name)
    task
  end

  def after_restore(*args, &block)
    task = Rake::Task.define_task(*args, &block)
    Rake::Task.define_task("after_pull" => task.name)
    task
  end

private

  def install_master_tasks
    name    = Rake.application.current_scope.join(':')
    @config = Spare.configurations[name]
    unless @config
      raise "No configuration for #{name} tasks"
    end

    name = [name, 'push'].flatten.join(':')

    unless Rake::Task.task_defined?(name)
      t = Rake::Task.define_task('push')
      t.add_description "Make a new backup and push it to the server."

      t = Rake::Task.define_task('pull', [:ref])
      t.add_description "Pull a backup and restore its content."

      Rake::Task.define_task("before_push")
      Rake::Task.define_task("checkin_backup" => 'before_push')
      Rake::Task.define_task("backup"         => 'checkin_backup')
      Rake::Task.define_task("after_push"     => 'backup')
      Rake::Task.define_task("push"           => 'after_push')

      Rake::Task.define_task('validate_pull')
      Rake::Task.define_task('before_pull'      => 'validate_pull')
      Rake::Task.define_task("restore"          => 'before_pull')
      Rake::Task.define_task("checkout_restore" => 'restore')
      Rake::Task.define_task("after_pull"       => 'checkout_restore')
      Rake::Task.define_task("pull"             => 'after_pull')

      Rake::Task.define_task('backup') do
        @config.storage.backup
      end

      Rake::Task.define_task('restore', [:ref]) do |t, args|
        @config.storage.restore(args[:ref])
      end

      Rake::Task.define_task('validate_pull', [:ref]) do |t, args|
        unless args[:ref]
          puts "Please provide a REF=<> argument"
          exit 1
        end
        @config.storage.validate_restore(args[:ref])
      end

      Rake::Task.define_task('before_pull' => 'push')

    end
  end

end