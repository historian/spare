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

  def include_files(files)
    case files
    when String
      @config.include_patterns << files
    when Array
      files.map { |file| include_files file }
    when Rake::FileList
      files.to_a.map { |file| include_files file }
    else
      raise "a File spec must be a String, FileList or Array"
    end
    self
  end

  def exclude_files(files)
    case files
    when String
      @config.exclude_patterns << files
    when Array
      files.map { |file| exclude_files file }
    when Rake::FileList
      files.to_a.map { |file| exclude_files file }
    else
      raise "a File spec must be a String, FileList or Array"
    end
    self
  end

  def before_backup(deps=[], &block)
    Rake::Task.define_task("before_backup" => deps, &block)
    self
  end

  def backup(deps=[], &block)
    Rake::Task.define_task("checkin_backup" => deps, &block)
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

  def restore(deps=[], &block)
    Rake::Task.define_task("checkout_restore" => deps, &block)
    self
  end

  def after_restore(deps=[], &block)
    Rake::Task.define_task("after_restore" => deps, &block)
    self
  end

private

  def install_master_tasks
    namespace = Rake.application.current_scope.join(':')
    @config   = Spare.configurations[namespace]
    unless @config
      raise "No configuration for #{namespace} tasks"
    end

    name = [namespace, 'push'].flatten.join(':')

    unless Rake::Task.task_defined?(name)
      t = Rake::Task.define_task('create', [:msg])
      t.add_description "Create a new backup."

      t = Rake::Task.define_task('restore', [:ref, :hard])
      t.add_description "Restore a backup."

      t = Rake::Task.define_task('fetch', [:ref])
      t.add_description "Fetch a backup from the remote server."

      t = Rake::Task.define_task('upload')
      t.add_description "Upload a backup to the remote server."

      t = Rake::Task.define_task('push')
      t.add_description "Make a new backup and push it to the server."

      t = Rake::Task.define_task('pull', [:ref, :hard])
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

      Rake::Task.define_task('backup_before_restore')
      Rake::Task.define_task('before_restore'   => 'backup_before_restore')
      Rake::Task.define_task("real_restore"     => 'before_restore')
      Rake::Task.define_task("checkout_restore" => 'real_restore')
      Rake::Task.define_task("after_restore"    => 'checkout_restore')
      Rake::Task.define_task("restore"          => 'after_restore')

      Rake::Task.define_task('real_backup') do |t, args|
        @config.storage.backup(args[:msg])
      end

      Rake::Task.define_task('backup_before_restore', [:hard]) do |t, args|
        unless args[:hard] == 'true'
          Rake::Task["#{namespace}:create"].invoke
        end
      end

      Rake::Task.define_task('real_restore', [:ref]) do |t, args|
        @config.storage.restore(args[:ref])
      end

      Rake::Task.define_task('upload') do
        @config.storage.upload
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
      Rake::Task.define_task("push" => ['create', 'upload'])

    end
  end

end