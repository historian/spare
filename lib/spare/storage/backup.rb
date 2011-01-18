class Spare::Storage::Backup

  attr_reader :locations, :aliases, :name

  def initialize(name, aliases=nil, locations=[])
    @name      = name
    @aliases   = aliases   ? aliases.dup   : []
    @locations = locations ? locations.dup : []
  end

  def merge(other)
    raise ArgumentError unless self.class === other and @name == other.name

    self.class.new(
      @name,
      (@aliases   + other.aliases).uniq,
      (@locations + other.locations).uniq
    )
  end

  def dup
    self.class.new(@name, @aliases, @aliases)
  end

  def to_s
    alias_list    = "(#{@aliases.join(', ')})"   unless @aliases.emtpy?
    location_list = "[#{@locations.join(', ')}]" unless @locations.emtpy?
    [@name, alias_list, location_list].join(' ')
  end

end