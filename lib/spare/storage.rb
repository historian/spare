class Spare::Storage

  class << self

    def adapters
      @adapters ||= { :git => Spare::Storage::Git }
    end

    def register_adapter(name, klass)
      self.adapters[name.to_sym] = klass
    end

  end

  def initialize(config, adapter_class)
    @config  = config
    @adapter = adapter_class.new(config)
  end

  def backup
    setup

    files = @config.backup_tasks.map do |_, task|
      task.resolve_files
    end.flatten

    if files.empty?
      $stderr.puts "Nothing to backup"
      return false
    end

    @adapter.backup(files.uniq.sort)
  ensure
    @local_backups = @all_backups = nil
  end

  def restore(ref)
    setup

    backup = find_backup(ref, :local)

    unless backup
      raise "No backup for ref: #{ref}"
    end

    @adapter.restore(backup)
  ensure
    @local_backups = @all_backups = nil
  end

  def upload
    setup

    non_remote_backups = all_backups.select do |backup|
      !backup.locations.include?(:remote)
    end

    if non_remote_backups.empty?
      $stdout.puts "Nothing to upload"
      return true
    end

    @adapter.upload(non_remote_backups)
  ensure
    @remote_backups = @all_backups = nil
  end

  def fetch(ref)
    setup

    backup = find_backup(ref, :all)

    unless backup
      raise "No backup for ref: #{ref}"
    end

    if backup.locations.include?(:local)
      puts "Already present in local repository"
      return true
    end

    @adapter.fetch(backup)
  ensure
    @local_backups = @all_backups = nil
  end

  def prune
    setup

    @adapter.prune
  ensure
    @local_backups = @all_backups = nil
  end

  def list_local
    setup

    puts "Local backups:"
    local_backups.each do |backup|
      puts "  #{backup}"
    end
  end

  def list_remote
    setup

    puts "Remote backups:"
    remote_backups.each do |backup|
      puts "  #{backup}"
    end
  end

  def list_all
    setup

    puts "All backups:"
    all_backups.each do |backup|
      puts "  #{backup}"
    end
  end

private

  def setup
    @is_setup ||= begin
      @adapter.setup
      true
    end
  end

  def find_backup(ref, location=:local)
    case location
    when :local  then backups = local_backups
    when :remote then backups = remote_backups
    when :all    then backups = all_backups
    else
      raise ArgumentError
    end

    backups.find do |backup|
      backup.name == ref or backup.aliases.include?(ref)
    end
  end

  def local_backups
    @local_backups ||= @adapter.local_backups
  end

  def remote_backups
    @remote_backups ||= @adapter.remote_backups
  end

  def all_backups
    @all_backups ||= begin
      refs = {}

      local_backups.each do |backup|
        refs[backup.name] = backup.dup
      end

      remote_backups.each do |backup|
        local = refs[backup.name]
        if local
          refs[backup.name] = backup.merge(local)
        else
          refs[backup.name] = backup.dup
        end
      end

      refs.values
    end
  end

end