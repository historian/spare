class Spare::Storage::Base
  
  attr_reader :config, :storage_config

  def initialize(config)
    @config = config
    @storage_config = @config.storage_config
  end

  def backup
    raise NotImplemented
  end

  def restore(backup)
    raise NotImplemented
  end

  def send(backup)
    raise NotImplemented
  end

  def fetch(backup)
    raise NotImplemented
  end

  def local_backups
    raise NotImplemented
  end

  def remote_backups
    raise NotImplemented
  end

  def prune
    raise NotImplemented
  end

end