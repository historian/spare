module Spare
  
  def self.configurations
    @configurations ||= {}
  end
  
  require 'spare/version'
  require 'spare/configuration'
  require 'spare/configuration/dsl'
  require 'spare/task'
  require 'spare/backup_task'
  require 'spare/restore_task'
  
  module Storage
  
    def self.adapters
      @adapters ||= { :git => Spare::Storage::Git }
    end
    
    def self.register_adapter(name, klass)
      self.adapters[name.to_sym] = klass
    end
    
    require 'spare/storage/git'
    
  end
  
end