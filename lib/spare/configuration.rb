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

    @include_patterns = []
    @exclude_patterns = []

    Spare::Configuration::DSL.new(self, &block) if block
  end

  attr_reader :name
  attr_accessor :storage, :storage_config, :include_patterns, :exclude_patterns

  def resolve_files
    files  = @include_patterns.flatten.uniq.sort
    files -= @exclude_patterns.flatten
    files.select { |path| File.file?(path) }
  end

end