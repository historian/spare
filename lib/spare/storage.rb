class Spare::Storage

  def initialize(config, adapter_class)
    @config  = config
    @adapter = adapter_class.new(config)
  end

  def backup
    @adapter.backup
  end

  def restore(ref)
    backup = find_backup(ref, :local)

    unless backup
      raise "No backup for ref: #{ref}"
    end

    @adapter.restore(backup)
  end

  def send(ref)
    backup = find_backup(ref, :all)

    unless backup
      raise "No backup for ref: #{ref}"
    end

    if backup.locations.include?(:remote)
      puts "Already present in remote repository"
      return true
    end

    @adapter.send(backup)
  end

  def fetch(ref)
    backup = find_backup(ref, :all)

    unless backup
      raise "No backup for ref: #{ref}"
    end

    if backup.locations.include?(:local)
      puts "Already present in local repository"
      return true
    end

    @adapter.fetch(backup)
  end

  def clean
    @adapter.clean
  end

private

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

  def list_local
    puts "Local backups:"
    local_backups.each do |backup|
      puts "  #{backup}"
    end
  end

  def list_remote
    puts "Remote backups:"
    remote_backups.each do |backup|
      puts "  #{backup}"
    end
  end

  def list_all
    puts "All backups:"
    all_backups.each do |backup|
      puts "  #{backup}"
    end
  end

end