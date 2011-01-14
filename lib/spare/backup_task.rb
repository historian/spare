class Spare::BackupTask < Rake::Task
  
  def initialize(*)
    @include_patterns = []
    @exclude_patterns = []
    super
  end
  
  def include(files)
    @include_patterns << files
    self
  end
  
  def exclude(files)
    @include_patterns << files
    self
  end
  
  def resolve_files
    files = []
    
    @include_patterns.each do |spec|
      case spec
      when String
        files << spec
      when Rake::FileList
        files.concat spec.to_a
      when Array
        files.concat spec
      else
        raise "a File spec must be a String, FileList or Array"
      end
    end
    
    files = files.uniq
    
    @exclude_patterns.each do |spec|
      case spec
      when String
        files.delete spec
      when Rake::FileList
        files -= spec.to_a
      when Array
        files -= spec
      else
        raise "a File spec must be a String, FileList or Array"
      end
    end
    
    files
  end
  
end