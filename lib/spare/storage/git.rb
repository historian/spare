class Spare::Storage::Git
  
  Spare::Storage.register_adapter(:git, self)
  
  def initialize(config)
    @config = config
  end
  
  def backup
    storage_config = @config.storage_config
    ENV['GIT_DIR']       = File.expand_path(storage_config[:repository])
    ENV['GIT_WORK_TREE'] = File.expand_path(".")
    
    # Ensure backup repo
    unless File.directory?(ENV['GIT_DIR'])
      out = `git init . 2>&1`
      unless $?.exitstatus == 0
        out = out.gsub("\n", "\n              ")
        puts "  *** FAILED: #{out}"
        return false
      end
    end
    
    files = []
    @config.backup_tasks.each do |_, task|
      files.concat task.resolve_files
    end
    files = files.uniq
    
    changes = []
    
    # Find changed files
    out = `git status --porcelain 2>&1`
    unless $?.exitstatus == 0
      out = out.gsub("\n", "\n              ")
      puts "  *** FAILED: #{out}"
      out = ""
    end
    
    out.split("\n").each do |line|
      line = line.strip
      status, path = line[0,1], line[3..-1]
      path, old_path = *path.split(/\s+\-\>\s+/, 2).reverse
      
      case status
      when ' '
        # ignore
      when 'R'
        changes << ['A', path] if files.include?(path)
        changes << ['D', old_path]
      when 'M', 'A', '?', 'C'
        status = 'A' if status == 'C' or status == '?'
        changes << [status, path]
      when 'D'
        changes << ['D', path]
      end
    end
    
    puts "git ls-tree --full-tree -r --name-only master 2>&1"
    out = `git ls-tree --full-tree -r --name-only master 2>&1`
    unless $?.exitstatus == 0
      out = out.gsub("\n", "\n              ")
      puts "  *** FAILED: #{out}"
      out = ""
    end
    
    puts out
    out.split("\n").each do |line|
      path = line.strip
      unless files.include?(path)
        changes << ['D', path]
      end
    end
    
    if changes.empty?
      puts "No changes since last backup."
      return
    end
    
    # Stage deleted/updated/new files
    changes.each do |(status, path)|
      case status
      when 'M', 'A'
        puts "#{status} #{path}"
        out = `git add -f #{path.inspect} 2>&1`
        unless $?.exitstatus == 0
          out = out.gsub("\n", "\n              ")
          puts "  *** FAILED: #{out}"
        end
        
      when 'D'
        puts "D #{path}"
        out = `git rm #{path.inspect} 2>&1`
        unless $?.exitstatus == 0
          out = out.gsub("\n", "\n              ")
          puts "  *** FAILED: #{out}"
        end

      end
    end
    
    # Commit changes
    timestamp = Time.now.strftime("Backup: %Y%m%d%H%M%S")
    out = `git commit -m #{timestamp.inspect} 2>&1`
    unless $?.exitstatus == 0
      out = out.gsub("\n", "\n              ")
      puts "  *** FAILED: #{out}"
    end
    
    # Push changes
    unless storage_config[:remote]
      puts "There is no remote storage configured."
      return
    end
    
    remote = storage_config[:remote].inspect
    branch = storage_config[:branch].inspect
    out = `git push #{remote} master:#{branch} 2>&1`
    unless $?.exitstatus == 0
      out = out.gsub("\n", "\n              ")
      puts "  *** FAILED: #{out}"
    end
  end
  
  def restore
    
  end
  
  class Configuration
    
    def repository(url)
      @repository = url
    end
    
    def remote(remote)
      @remote = remote
    end
    
    def branch(branch)
      @branch = branch
    end
    
    def to_options
      {
        :repository => (@repository || 'backup.git'),
        :remote     => @remote,
        :branch     => (@branch || 'master')
      }
    end
    
  end
  
end