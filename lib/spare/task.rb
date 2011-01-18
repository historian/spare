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

  def before_backup(deps=[], &block)
    Rake::Task.define_task("before_backup" => deps, &block)
    self
  end

  def backup(&block)
    task = Spare::BackupTask.define_task("#{@base_name}:backup", &block)
    @config.backup_tasks[task.name] = task
    Rake::Task.define_task("checkin_backup" => task.name)
    self
  end

  def after_backup(deps=[], &block)
    Rake::Task.define_task("after_backup" => deps, &block)
    self
  end

  def before_restore(deps=[], &block)
    Rake::Task.define_task("before_restore" => deps, &block)
    self
  end

  def restore(&block)
    task = Spare::RestoreTask.define_task("#{@base_name}:restore", &block)
    @config.restore_tasks[task.name] = task
    Rake::Task.define_task("checkout_restore" => task.name)
    self
  end

  def after_restore(deps=[], &block)
    Rake::Task.define_task("after_restore" => deps, &block)
    self
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
      t = Rake::Task.define_task('create')
      t.add_description "Create a new backup."

      t = Rake::Task.define_task('restore', [:ref])
      t.add_description "Restore a backup."

      t = Rake::Task.define_task('fetch', [:ref])
      t.add_description "Fetch a backup from the remote server."

      t = Rake::Task.define_task('update')
      t.add_description "Send a backup to the remote server."

      t = Rake::Task.define_task('push')
      t.add_description "Make a new backup and push it to the server."

      t = Rake::Task.define_task('pull', [:ref])
      t.add_description "Pull a backup and restore its content."

      t = Rake::Task.define_task('prune')
      t.add_description "Remove unused backups from the local repository."

      Rake.application.in_namespace 'list' do

        t = Rake::Task.define_task('local')
        t.add_description "List local backups."

        t = Rake::Task.define_task('remote')
        t.add_description "List remote backups."

        t = Rake::Task.define_task('all')
        t.add_description "List all backups."

      end

      Rake::Task.define_task("before_backup")
      Rake::Task.define_task("checkin_backup" => 'before_backup')
      Rake::Task.define_task("real_backup"    => 'checkin_backup')
      Rake::Task.define_task("after_backup"   => 'real_backup')
      Rake::Task.define_task("create"         => 'after_backup')

      Rake::Task.define_task('before_restore')
      Rake::Task.define_task("real_restore"     => 'before_restore')
      Rake::Task.define_task("checkout_restore" => 'real_restore')
      Rake::Task.define_task("after_restore"    => 'checkout_restore')
      Rake::Task.define_task("restore"          => 'after_restore')

      Rake::Task.define_task('real_backup') do
        @config.storage.backup
      end

      Rake::Task.define_task('real_restore', [:ref]) do |t, args|
        @config.storage.restore(args[:ref])
      end

      Rake::Task.define_task('update') do
        @config.storage.update
      end

      Rake::Task.define_task('fetch', [:ref]) do |t, args|
        @config.storage.fetch(args[:ref])
      end

      Rake::Task.define_task('prune') do
        @config.storage.prune
      end

      Rake::Task.define_task('list:local') do
        @config.storage.list_local
      end

      Rake::Task.define_task('list:remote') do
        @config.storage.list_remote
      end

      Rake::Task.define_task('list:all') do
        @config.storage.list_all
      end

      Rake::Task.define_task("pull" => ['fetch', 'restore'])
      Rake::Task.define_task("push" => ['create', 'send'])

    end
  end

end