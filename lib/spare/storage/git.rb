class Spare::Storage::Git < Spare::Storage::Base

  Spare::Storage.register_adapter(:git, self)

  require 'shellwords'
  SH = ::Shellwords

  def setup
    ENV['GIT_DIR']       = File.expand_path(repository)
    ENV['GIT_WORK_TREE'] = File.expand_path(".")

    unless File.directory?(ENV['GIT_DIR'])
      system "git init ."
      unless $?.exitstatus == 0
        raise "Failed to init git repo"
      end
    end
  end

  def backup(files)
    symlinks = find_symlinks(files)
    replace_symlinks_with_hardlinks(symlinks)
    
    changes = determine_changed_files(files)

    if changes.empty?
      $stderr.puts "No changes since last backup."
      return false
    end

    # Stage deleted/updated/new files
    changes.each do |(status, path)|
      case status
      when 'M', 'A'
        `git add --force #{SH.escape(path)}`
        unless $?.exitstatus == 0
          $stderr.puts "Failed to add '#{path}'"
        else
          $stdout.puts "#{status} #{path}"
        end

      when 'D'
        `git rm --cached #{SH.escape(path)}`
        unless $?.exitstatus == 0
          $stderr.puts "Failed to delete '#{path}'"
        else
          $stdout.puts "D #{path}"
        end

      end
    end

    # Commit changes
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    message   = <<-EOM.gsub(/^    /m, '').strip
    Backup (at #{timestamp})
      remote: #{remote}
      branch: #{branch}
    EOM

    system "git commit -m #{SH.escape(message)}"
    $?.exitstatus != 0
  ensure
    replace_hardlinks_with_symlinks(symlinks)
    @head = @local_backups = nil
  end

  def restore(backup)
    lines = `git tag --contains #{head}`
    if $?.exitstatus == 0
      needs_a_tag = (lines.strip.length == 0)
    else
      needs_a_tag = false
    end

    unless needs_a_tag
      line = `git rev-list --children --all | grep '^#{head}'`
      if $?.exitstatus == 0
        needs_a_tag = (line.strip.split(/\s+/).size == 1)
      else
        needs_a_tag = false
      end
    end

    if needs_a_tag
      timestamp = Time.now.strftime("%Y%m%d%H%M%S")
      message   = <<-EOM.gsub(/^      /m, '').strip
      Restoring a backup (at #{timestamp})
        remote: #{remote}
        branch: #{branch}
      EOM

      system "git tag -a -m #{SH.escape(message)} #{SH.escape(timestamp)}"
      if $?.exitstatus != 0
        return false
      end

      @local_backups = nil
    end
    
    symlinks = nil
    files = `git ls-tree --name-only --full-tree -r #{SH.escape(backup.name)}`
    if $?.exitstatus == 0
      files = files.strip.split("\n")
      symlinks = find_symlinks(files)
      replace_symlinks_with_hardlinks(symlinks)
    else
      return false
    end

    system "git reset --hard #{SH.escape(backup.name)}"
    $?.exitstatus == 0
  ensure
    replace_hardlinks_with_symlinks(symlinks) if symlinks
    @head = nil
  end

  def upload(backups)
    backups = backups.select do |backup|
      !backup.aliases.empty?
    end

    if backups.empty?
      $stdout.puts "Nothing to upload"
      return true
    end

    system "git push #{SH.escape(remote)} --tags master:#{SH.escape(branch)} --force"
    $?.exitstatus == 0

  ensure
    @remote_backups = nil
  end

  def fetch(backup)
    if backup.aliases.empty?
      $stderr.puts "Git fetch needs a named backup"
      return false
    end

    target = backup.aliases.first

    system "git fetch #{SH.escape(remote)} #{SH.escape(target)}"
    $?.exitstatus == 0

  ensure
    @local_backups = nil
  end

  def prune
    refs = []

    tags = `git tag`
    if $?.exitstatus == 0
      tags = tags.strip.split("\n")
      tags = tags.each do |tag|
        ref = `git rev-parse --symbolic-full-name #{SH.escape(tag)}`
        refs << ref.strip if $?.exitstatus == 0
      end
    end

    branches = `git branch -a --no-color`
    if $?.exitstatus == 0
      branches = branches.strip.split("\n")
      branches = branches.map { |branch| branch.sub(/^[* ][ ]/, '').split('->', 2).first.strip }
      branches.each do |branch|
        ref = `git rev-parse --symbolic-full-name #{SH.escape(branch)}`
        refs << ref.strip if $?.exitstatus == 0
      end
    end

    refs.delete('refs/heads/master')
    refs.each do |ref|
      `git update-ref -d #{ref}`
    end

    last_ref = `git log -n 1 --skip 5 --format=%H master`
    if $?.exitstatus == 0 and last_ref.strip.length > 0
      File.open(File.join(ENV['GIT_DIR'], 'shallow'), 'w+') do |file|
        file.puts last_ref
      end
    end

    system "git gc"
    system "git prune"

    true
  ensure
    @local_backups = nil
  end

  def local_backups
    @local_backups ||= begin
      o = `git log --format="%H %d" --all`

      unless $?.exitstatus == 0
        return []
      end

      o.strip.split("\n").map do |line|
        sha, refs = line.split(/\s+/, 2)
        refs = refs ? (refs[1..-2] || "").split(', ') : []
        refs.delete('HEAD')
        Spare::Storage::Backup.new(sha, refs, [:local])
      end

    end
  end

  def remote_backups
    @remote_backups ||= begin
      o = `git ls-remote #{SH.escape(remote)}`

      unless $?.exitstatus == 0
        return []
      end

      refs = {}

      o.strip.split("\n").map do |line|
        sha, ref = line.split(/\s+/, 2)
        unless ref =~ /\^\{\}$/
          ref = ref.sub(/^refs\/(heads|tags)\//, '')
          (refs[sha] ||= []) << ref
        end
      end

      refs.map do |sha, refs|
        Spare::Storage::Backup.new(sha, refs, [:remote])
      end
    end
  end

private

  def head
    @head ||= begin
      head = `git rev-parse HEAD`
      $?.exitstatus == 0 ? head.strip : nil
    end
  end

  def remote
    storage_config.remote || raise("No remote was configured.")
  end

  def branch
    storage_config.branch || 'master'
  end

  def repository
    storage_config.repository || 'tmp/backup.git'
  end

  def determine_changed_files(files)
    remaining_files = files.dup
    changes         = []

    # Find changed files
    out = `git status --porcelain`
    if $?.exitstatus == 0
      out.split("\n").each do |line|
        line = line.strip
        status, path = line[0,1], line[2..-1].strip
        path, old_path = *path.split(/\s+\-\>\s+/, 2).reverse

        case status
        when ' '
          # ignore
        when 'R'
          changes << ['A', path] if files.include?(path)
          changes << ['D', old_path]
        when 'M', 'A', '?', 'C'
          status = 'A' if status == 'C' or status == '?'
          changes << [status, path] if files.include?(path)
        when 'D'
          changes << ['D', path]
        end
        remaining_files.delete(path)
      end
    end

    out = `git ls-tree --full-tree -r --name-only master`
    if $?.exitstatus == 0
      out.split("\n").each do |line|
        path = line.strip
        unless files.include?(path)
          changes << ['D', path]
        end
        remaining_files.delete(path)
      end
    end

    remaining_files.each do |path|
      next unless File.file?(path)
      changes << ['A', path]
    end

    changes.uniq
  end
  
  def find_symlinks(files)
    checked_paths = {}
    symlinks      = {}
    
    root = File.expand_path('.')
    
    files.each do |path|
      find_symlinks_in_path(root, path, checked_paths, symlinks)
    end
    
    symlinks
  end
  
  def find_symlinks_in_path(root, path, checked_paths, symlinks)
    path = File.expand_path(path)
    
    until path == root
      return if checked_paths.key?(path)
      
      if File.symlink?(path)
        link   = File.readlink(path)
        target = File.expand_path(link, File.dirname(path))
        symlinks[path] = [target, link]
      end
      
      checked_paths[path] = true
      path = File.dirname(path)
    end
  end
  
  def replace_symlinks_with_hardlinks(symlinks)
    symlinks.each do |path, (target, link)|
      File.unlink(path)
      File.link(target, path)
    end
  end
  
  def replace_hardlinks_with_symlinks(symlinks)
    symlinks.each do |path, (target, link)|
      File.unlink(path)
      File.symlink(link, path)
    end
  end

end