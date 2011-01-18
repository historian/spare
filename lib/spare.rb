module Spare

  def self.configurations
    @configurations ||= {}
  end

  require 'rake'

  require 'spare/version'
  require 'spare/configuration'
  require 'spare/configuration/dsl'
  require 'spare/task'
  require 'spare/backup_task'
  require 'spare/restore_task'
  require 'spare/storage'
  
  class Storage
    require 'spare/storage/backup'
    require 'spare/storage/base'
    require 'spare/storage/git'
  end

end