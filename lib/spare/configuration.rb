class Spare::Configuration

  class << self

    alias_method :real_new, :new

    def new(name=nil, &block)
      if !name and Rake.application.current_scope.empty?
        name = 'backup'
      end

      name = (Rake.application.current_scope + [name]).compact.join(':')

      Spare.configurations[name] ||= Spare::Configuration.real_new(name, &block)
    end

  end

  def initialize(name, &block)
    @name  = name
    @backup_tasks  = {}
    @restore_tasks = {}
    Spare::Configuration::DSL.new(self, &block) if block
  end

  attr_reader :name, :restore_tasks, :backup_tasks
  attr_accessor :storage, :storage_config


end