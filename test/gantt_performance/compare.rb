# frozen_string_literal: true

require 'rbconfig'
require 'fileutils'
require 'open3'

root = File.expand_path(ENV.fetch('GANTT_PERF_ROOT'))
before_root = File.expand_path(ENV.fetch('GANTT_PERF_BEFORE_ROOT'))
after_root = File.expand_path(ENV.fetch('GANTT_PERF_AFTER_ROOT'))
seed_database = File.expand_path(ENV.fetch('GANTT_PERF_SEED_DATABASE'))
manifest = File.expand_path(ENV.fetch('GANTT_PERF_MANIFEST'))
runner = File.expand_path('run.rb', __dir__)
analyzer = File.expand_path('analyze.rb', __dir__)
git_common_dir, git_status = Open3.capture2(
  'git', '-c', "safe.directory=#{after_root}", '-C', after_root, 'rev-parse', '--git-common-dir'
)
abort 'Unable to locate the shared Git directory' unless git_status.success?
git_common_dir = File.expand_path(git_common_dir.strip, after_root)
before_lock = File.join(before_root, 'Gemfile.lock')
after_lock = File.join(after_root, 'Gemfile.lock')
unless File.file?(before_lock) && File.file?(after_lock) && FileUtils.compare_file(before_lock, after_lock)
  abort 'Gemfile.lock must exist and match in both checkouts'
end

[["before", 1, before_root], ["after", 1, after_root],
 ["after", 2, after_root], ["before", 2, before_root]].each do |label, round, app_root|
  command = ['bundle', 'exec', RbConfig.ruby, runner, label, round.to_s, root, app_root, seed_database, manifest]
  puts command.join(' ')
  environment = {
    'BUNDLE_GEMFILE' => File.join(app_root, 'Gemfile'),
    'BUNDLE_BIN_PATH' => nil,
    'BUNDLER_VERSION' => nil,
    'GANTT_PERF_GIT_COMMON_DIR' => git_common_dir,
    'RUBYLIB' => nil,
    'RUBYOPT' => nil
  }
  abort "#{label} round #{round} failed" unless system(environment, *command, :chdir => app_root)
end

abort 'analysis failed' unless system(RbConfig.ruby, analyzer, root)
