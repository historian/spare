class Spare::BackupTask < Rake::Task

  def initialize(*)
    @include_patterns = []
    @exclude_patterns = []
    super
  end

  def include(files)
    case files
    when String
      @include_patterns << files
    when Array
      files.map { |file| include file }
    when Rake::FileList
      files.to_a.map { |file| include file }
    else
      raise "a File spec must be a String, FileList or Array"
    end
    self
  end

  def exclude(files)
    case files
    when String
      @exclude_patterns << files
    when Array
      files.map { |file| exclude file }
    when Rake::FileList
      files.to_a.map { |file| exclude file }
    else
      raise "a File spec must be a String, FileList or Array"
    end
    self
  end

  def resolve_files
    @include_patterns.uniq.sort - @exclude_patterns
  end

end