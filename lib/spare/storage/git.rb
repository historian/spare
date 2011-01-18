class Spare::Storage::Git < Spare::Storage::Base

  def backup
    raise NotImplemented
  end

  def restore(backup)
    raise NotImplemented
  end

  def send(backup)
    raise NotImplemented
  end

  def fetch(backup)
    if backup.aliases.empty?
      puts "Git fetch needs a named backup"
      return false
    end

    git(:fetch, remote, backup.aliases.first) do |s, o|
      return s == 0
    end
  end

  def local_backups
    git(:log, '--format=%H %d', '--all') do |s, o|
      return [] unless s == 0

      o.split("\n").map do |line|
        sha, refs = line.split(/\s+/, 2)
        refs = refs ? refs[1..-2].split(', ') : []
        Spare::Storage::Backup.new(sha, refs, [:local])
      end
    end
  end

  def remote_backups
    git('ls-remote', remote) do |s, o|
      return [] unless s == 0

      refs = {}

      o.split("\n").map do |line|
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

  def clean
    raise NotImplemented
  end

private

  def remote
    storage_config[:remote]
  end

  def branch
    storage_config[:branch]
  end

  def repository
    storage_config[:repository]
  end



=begin
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
    remaining_files = files.dup

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
          remaining_files.delete(path)
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
          remaining_files.delete(path)
        end
      elsif out !~ /Not a valid object name master/
        show_error(out)
      end
    end

    remaining_files.each do |path|
      next unless File.file?(path)
      changes << ['A', path]
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

    if $actual_task == 'restore'
      puts "defer push"
      return
    end

    remote = storage_config[:remote]
    branch = storage_config[:branch]
    git(:push, remote, "master:#{branch}")

    cleanup
  end

  def validate_restore(ref)
    $actual_task = 'restore'

    storage_config       = @config.storage_config
    remote               = storage_config[:remote]
    branch               = storage_config[:branch]
    ENV['GIT_DIR']       = File.expand_path(storage_config[:repository])
    ENV['GIT_WORK_TREE'] = File.expand_path(".")

    unless File.directory?(ENV['GIT_DIR'])
      unless git(:init, '.')
        exit 1
      end

      refs = get_remote_refs(remote)

      if refs and refs[ref]
        @fetch_ref     = ref
        @local_restore = refs[ref]
      elsif refs and refs["refs/heads/#{ref}"]
        @fetch_ref     = ref
        @local_restore = refs["refs/heads/#{ref}"]
      elsif refs and refs["refs/tags/#{ref}"]
        @fetch_ref     = ref
        @local_restore = refs["refs/tags/#{ref}"]
      end

      if @local_restore
        return
      end

      puts "Initial restore needs a named ref (eg. master)"
      exit 1

    else

      @current_ref = git(:log, '-n', 1, '--format=format:%H', 'master')

      refs = get_local_refs
      if refs
        if refs[ref]
          @local_restore = refs[ref]
        elsif refs.any? { |sha| sha == ref }
          @local_restore = ref
        elsif refs[:_anon].include?(ref)
          @local_restore = ref
        end
      end

      if @local_restore
        return
      end

      refs = get_remote_refs(remote)
      if refs and refs[ref]
        @fetch_ref     = ref
        @local_restore = refs[ref]
      elsif refs and refs["refs/heads/#{ref}"]
        @fetch_ref     = ref
        @local_restore = refs["refs/heads/#{ref}"]
      elsif refs and refs["refs/tags/#{ref}"]
        @fetch_ref     = ref
        @local_restore = refs["refs/tags/#{ref}"]
      end

      if @local_restore
        return
      end

      deepen_history(remote)
      refs = get_local_refs(true)

      if refs
        if refs[ref]
          @local_restore = refs[ref]
        elsif refs.any? { |sha| sha == ref }
          @local_restore = ref
        elsif refs[:_anon].include?(ref)
          @local_restore = ref
        end
      end

      if @local_restore
        return
      end

      cleanup
      puts "Ref (#{ref}) was not found."
      exit 1

    end

    if @current_ref and @local_restore == @current_ref
      cleanup
      puts "Already at #{@current_ref}"
      exit 1
    end
  end

  def restore(ref)
    storage_config       = @config.storage_config
    remote               = storage_config[:remote]
    branch               = storage_config[:branch]
    ENV['GIT_DIR']       = File.expand_path(storage_config[:repository])
    ENV['GIT_WORK_TREE'] = File.expand_path(".")
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")

    if @fetch_ref
      git(:fetch, '--depth=5', remote, @fetch_ref)
    end

    remote_tags = get_remote_tags(remote)

    @current_ref = git(:log, '-n', 1, '--format=format:%H', 'master')
    if @current_ref and !remote_tags.values.include?(@current_ref)
      message = <<-EOM
      Restoring a backup (at #{timestamp})
        remote: #{remote}
        branch: #{branch}
       old ref: #{@current_ref}
       new ref: #{@local_restore}
      EOM
      message = message.gsub(/^      /m, '').strip

      git(:tag, '-a', '-m', message, timestamp)
      git(:push, remote, '--tags')
    end

    git(:reset, '--hard', @local_restore)
    git(:push, remote, "master:#{branch}", '--force')

    cleanup
  end

private

  def cleanup
    storage_config = @config.storage_config
    remote         = storage_config[:remote]
    branch         = storage_config[:branch]

    refs = get_local_refs(true)
    refs.delete(:_anon)
    refs.delete('HEAD')
    refs.delete('master')

    refs.each do |(ref, _)|
      ref = git('rev-parse', '--symbolic-full-name', ref)
      next unless ref

      ref = ref.strip
      git('update-ref', '-d', ref)
    end

    last_ref = git(:log, '-n', 1, '--skip', 5, '--format=format:%H', 'master')

    if last_ref and last_ref.strip != ""
      File.open(File.join(ENV['GIT_DIR'], 'shallow'), 'w+') do |file|
        file.puts last_ref
      end

      git(:gc)
      git(:prune)
      git(:fsck)
    end
  end

  def deepen_history(remote)
    git(:fetch, '--depth=100000000', remote, 'refs/heads/*:refs/remotes/origin/*')
  end

  def get_remote_tags(remote)
    raw = nil

    git('ls-remote', '--tags', remote) do |s, o|
      return false unless s == 0
      raw = o.strip
    end

    refs = raw.split("\n").map do |line|
      line.split(/\s+/, 2).reverse
    end.flatten

    Hash[*refs]
  end

  def get_remote_refs(remote)
    raw = nil

    git('ls-remote', '--heads', '--tags', remote) do |s, o|
      return false unless s == 0
      raw = o.strip
    end

    refs = raw.split("\n").map do |line|
      line.split(/\s+/, 2).reverse
    end.flatten

    Hash[*refs]
  end

  def get_local_refs(all=false)
    raw = nil

    which = (all ? '--all' : 'master')

    git('rev-list', '--format=tformat:%d', which) do |s, o|
      return false unless s == 0
      raw = o.strip
    end

    shas = {}
    raw.split("\n").inject(nil) do |last, line|
      case line
      when /^commit (.+)$/
        shas[$1] = []
        $1
      when /^ \(([^)]+)\)$/
        shas[last].concat $1.split(', ')
        last
      end
    end

    refs = { :_anon => [] }
    shas.each do |sha, names|
      if names.empty?
        refs[:_anon] << sha
      else
        names.each do |name|
          refs[name] = sha
        end
      end
    end

    refs
  end

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
=end

end