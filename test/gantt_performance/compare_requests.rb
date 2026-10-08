# frozen_string_literal: true
# rubocop:disable all

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'

root = File.expand_path(ENV.fetch('GANTT_PERF_ROOT'))
apps = {'before' => File.expand_path(ENV.fetch('GANTT_PERF_BEFORE_ROOT')),
        'after' => File.expand_path(ENV.fetch('GANTT_PERF_AFTER_ROOT'))}
seed = File.expand_path(ENV.fetch('GANTT_PERF_SEED_DATABASE'))
manifest = File.expand_path(ENV.fetch('GANTT_PERF_MANIFEST'))
raise 'Dedicated output and seed paths required' unless [root, seed].all? {|path| path.include?('/gantt_performance/')}
locks = apps.values.map {|app| File.join(app, 'Gemfile.lock')}
raise 'Gemfile.lock must match in both checkouts' unless locks.all? {|path| File.file?(path)} && FileUtils.compare_file(*locks)
scenarios = ENV.fetch('GANTT_PERF_SCENARIOS', 'normal,heavy').split(',')
modes = ENV.fetch('GANTT_PERF_REQUEST_MODES', 'timing,memory').split(',')
raise 'Choose normal and/or heavy' unless scenarios.any? && (scenarios - %w[normal heavy]).empty?
raise 'Choose timing and/or memory' unless modes.any? && (modes - %w[timing memory]).empty?
rounds = Integer(ENV.fetch('GANTT_PERF_REQUEST_ROUNDS', '2'))
memory_runs = Integer(ENV.fetch('GANTT_PERF_MEMORY_RUNS', '3'))
raise 'Run counts must be positive' unless rounds.positive? && memory_runs.positive?

common, status = Open3.capture2('git', '-c', "safe.directory=#{apps['after']}", '-C', apps['after'], 'rev-parse', '--git-common-dir')
raise 'Shared Git directory not found' unless status.success?
common = File.expand_path(common.strip, apps['after'])
git = lambda do |app, *args|
  command = ['git', '-c', "safe.directory=#{app}", '-C', app]
  output, error, status = Open3.capture3(*command, *args)
  unless status.success?
    git_file = File.join(app, '.git')
    raise error unless File.file?(git_file)
    admin = File.basename(File.read(git_file).delete_prefix('gitdir:').strip)
    output, error, status = Open3.capture3('git', '-c', "safe.directory=#{app}",
      "--git-dir=#{File.join(common, 'worktrees', admin)}", "--work-tree=#{app}", *args)
  end
  raise error unless status.success?
  output.strip
end
metadata = apps.to_h do |label, app|
  [label, {'label' => label, 'revision' => git.call(app, 'rev-parse', 'HEAD'),
           'dirty' => !git.call(app, 'status', '--porcelain').empty?, 'app_root' => app,
           'seed_sha256' => Digest::SHA256.file(seed).hexdigest,
           'bundle_sha256' => Digest::SHA256.file(locks.first).hexdigest,
           'manifest_sha256' => Digest::SHA256.file(manifest).hexdigest}]
end
output = File.join(root, 'requests')
raise 'Choose a fresh result root; requests/ already exists' if File.exist?(output)
FileUtils.mkdir_p(output)
records = []
$stdout.sync = true

modes.each do |mode|
  count = mode == 'timing' ? rounds : memory_runs
  count.times do |index|
    labels = index.even? ? %w[before after] : %w[after before]
    labels.each do |label|
      scenarios.each do |scenario|
        name = "#{mode}-#{label}-#{scenario}-#{index + 1}"
        database = File.join(output, "#{name}.sqlite3")
        result = File.join(output, "#{name}.json")
        log = File.join(output, "#{name}.log")
        FileUtils.cp(seed, database)
        env = {
          'BUNDLE_GEMFILE' => File.join(apps[label], 'Gemfile'), 'BUNDLE_BIN_PATH' => nil, 'BUNDLER_VERSION' => nil,
          'RAILS_ENV' => 'production', 'DATABASE_URL' => "sqlite3:#{database}", 'SECRET_KEY_BASE_DUMMY' => '1',
          'RUBYOPT' => "-r#{File.expand_path('frozen_clock.rb', __dir__)}", 'RUBYLIB' => nil,
          'GANTT_PERF_REQUEST_MODE' => mode, 'GANTT_PERF_SCENARIO' => scenario,
          'GANTT_PERF_MANIFEST' => manifest, 'GANTT_PERF_REQUEST_OUTPUT' => result,
          'GANTT_PERF_REQUEST_METADATA' => JSON.generate(metadata[label].merge('round' => index + 1))
        }
        puts "#{name}: starting independent Rails process"
        success = File.open(log, 'w') do |stream|
          system(env, RbConfig.ruby, 'bin/rails', 'runner', File.expand_path('request.rb', __dir__),
                 :chdir => apps[label], :out => stream, :err => stream)
        end
        raise "#{name} failed; see #{log}" unless success
        records << File.basename(result)
      end
    end
  end
end
File.write(File.join(output, 'index.json'), JSON.pretty_generate('records' => records))
raise 'Request analysis failed' unless system(RbConfig.ruby, File.expand_path('analyze_requests.rb', __dir__), output)
