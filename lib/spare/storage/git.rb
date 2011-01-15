class Spare::Storage::Git

  require 'shellwords'

  Spare::Storage.register_adapter(:git, self)

  def initialize(config)
    @config = config
  end

  def backup
    storage_config       = @config.storage_config
    ENV['GIT_DIR']       = File.expand_path(storage_config[:repository])
    ENV['GIT_WORK_TREE'] = File.expand_path(".")

    # Ensure backup repo
    unless File.directory?(ENV['GIT_DIR'])
      return unless git(:init, '.')
    end

    files = []
    @config.backup_tasks.each do |_, task|
      files.concat task.resolve_files
    end
    files = files.uniq.sort

    changes = []

    # Find changed files
    git(:status, '--porcelain') do |s, out|
      if s == 0
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
        end
      else
        show_error(out)
      end
    end

    git('ls-tree', '--full-tree', '-r', '--name-only', 'master') do |s, out|
      if s == 0
        out.split("\n").each do |line|
          path = line.strip
          unless files.include?(path)
            changes << ['D', path]
          end
        end
      elsif out !~ /Not a valid object name master/
        show_error(out)
      end
    end

    if changes.empty?
      puts "No changes since last backup."
      return
    end

    changes = changes.uniq

    # Stage deleted/updated/new files
    changes.each do |(status, path)|
      case status
      when 'M', 'A'
        puts "#{status} #{path}"
        with_indent(1) { git(:add, '-f', path) }

      when 'D'
        puts "D #{path}"
        with_indent(1) { git(:rm, '--cached', path) }

      end
    end

    # Commit changes
    timestamp = Time.now.strftime("Backup: %Y%m%d%H%M%S")
    git(:commit, '-m', timestamp)

    # Push changes
    unless storage_config[:remote]
      puts "There is no remote storage configured."
      return
    end

    remote = storage_config[:remote]
    branch = storage_config[:branch]
    git(:push, remote, "master:#{branch}")
  end

  def restore(ref)
    storage_config       = @config.storage_config
    remote               = storage_config[:remote]
    branch               = storage_config[:branch]
    ENV['GIT_DIR']       = File.expand_path(storage_config[:repository])
    ENV['GIT_WORK_TREE'] = File.expand_path(".")
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")

    unless File.directory?(ENV['GIT_DIR'])
      return unless git(:init, '.')
    end

    rem_ref = git('ls-remote', '--heads', '--tags', remote)
    if rem_ref
      rem_ref = rem_ref.split("\n").map do |line|
        line.split(/\s+/, 2).reverse
      end.flatten

      rem_ref = Hash[*rem_ref]
      rem_ref = rem_ref[ref]
    end

    old_ref = git(:log, '-n', 1, '--format=format:%H', 'master')

    if rem_ref and rem_ref == old_ref
      puts "Already at #{rem_ref}"
      return
    end

    if ref == old_ref
      puts "Already at #{ref}"
      return
    end

    if old_ref
      message = <<-EOM
      Restoring a backup (at #{timestamp})
        remote: #{remote}
        branch: #{branch}
       old ref: #{old_ref}
       new ref: #{ref}
      EOM
      message = message.gsub(/^      /m, '').strip

      git(:tag, '-a', '-m', message, timestamp)
      git(:push, remote, '--tags')
      git(:push, remote, ":#{branch}")
    end

    git(:fetch, '--depth=4', remote, ref)
    git(:reset, '--hard', ref)
    git(:push, remote, "master:#{branch}")
  end

private

  def sh(*cmd)
    cmd = cmd.flatten.compact.map { |i| i.to_s }
    cmd = Shellwords.join(cmd) + ' 2>&1'

    output = `#{cmd}`
    status = $?.exitstatus

    if block_given?
      yield(status, output)
    elsif status != 0
      show_error(output)
      false
    else
      output
    end
  end

  def git(*cmd, &block)
    sh('git', *cmd, &block)
  end

  def show_error(out, indent=nil)
    indent ||= (@indent || 0)

    out = "*** FAILED:\n#{out}"
    out = out.gsub("\n", "\n" + ("  " * indent))
    $stderr.puts out
    $stderr.flush
  end

  def with_indent(level)
    _indent, @indent = @indent = level
    yield
  ensure
    @indent = _indent
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