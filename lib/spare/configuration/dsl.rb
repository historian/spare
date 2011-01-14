class Spare::Configuration::DSL
  
  def initialize(config, &block)
    @config = config
    instance_eval(&block)
  end
  
  def storage(type, &block)
    storage = Spare::Storage.adapters[type.to_sym]
    @config.storage = storage
    
    config = (storage.const_get('Configuration') rescue nil)
    if config
      config = config.new
      config.instance_eval(&block)
      @config.storage_config = config.to_options
    end
    
    self
  end
  
end