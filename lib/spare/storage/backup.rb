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
    self.class.new(@name, @aliases, @locations)
  end

  def to_s
    alias_list    = "(#{@aliases.join(', ')})"   unless @aliases.empty?
    location_list = "[#{@locations.join(', ')}]" unless @locations.empty?
    [@name, alias_list, location_list].compact.join(' ')
  end

end