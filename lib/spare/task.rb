class Spare::Task
  
  def initialize(base_name, &block)
    @base_name = base_name
    
    if Rake.application.current_scope.empty?
      Rake.application.in_namespace 'data' do
        install_master_tasks
        instance_eval(&block)
      end
    else
      install_master_tasks
      instance_eval(&block)
    end
  end
  
  def before_backup(*args, &block)
    task = Rake::Task.define_task(*args, &block)
    Rake::Task.define_task("before_backup" => task.name)
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
    Rake::Task.define_task("after_backup" => task.name)
    task
  end
  
  def before_restore(*args, &block)
    task = Rake::Task.define_task(*args, &block)
    Rake::Task.define_task("before_restore" => task.name)
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
    Rake::Task.define_task("after_restore" => task.name)
    task
  end
  
private
  
  def install_master_tasks
    name    = Rake.application.current_scope.join(':')
    @config = Spare.configurations[name]
    unless @config
      raise "No configuration for #{name} tasks"
    end
    
    name = [name, 'backup'].flatten.join(':')
    
    unless Rake::Task.task_defined?(name)
      t = Rake::Task.define_task('backup')
      t.add_description "Make a new backup"
      
      t = Rake::Task.define_task('restore')
      t.add_description "Restore a backup"
      
      Rake::Task.define_task("before_backup")
      Rake::Task.define_task("checkin_backup" => 'before_backup')
      Rake::Task.define_task("real_backup"    => 'checkin_backup')
      Rake::Task.define_task("real_backup"    => 'before_backup')
      Rake::Task.define_task("after_backup"   => 'real_backup')
      Rake::Task.define_task("backup"         => 'after_backup')
      
      Rake::Task.define_task('before_restore')
      Rake::Task.define_task("real_restore"     => 'before_restore')
      Rake::Task.define_task("checkout_restore" => 'real_restore')
      Rake::Task.define_task("after_restore"    => 'checkout_restore')
      Rake::Task.define_task("restore"          => 'after_restore')
      
      Rake::Task.define_task('real_backup') do
        @config.storage.new(@config).backup
      end
      
      Rake::Task.define_task('real_restore') do
        @config.storage.new(@config).restore
      end
      
    end
  end
  
end