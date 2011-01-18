class Spare::Configuration::DSL
  
  require 'ostruct'
  
  def initialize(config, &block)
    @config = config
    instance_eval(&block)
  end
  
  def storage(type, &block)
    storage = Spare::Storage.adapters[type.to_sym]
    
    @config.storage_config = OpenStruct.new
    block.call(@config.storage_config) if block
    
    @config.storage = Spare::Storage.new(@config, storage)
    
    self
  end
  
end