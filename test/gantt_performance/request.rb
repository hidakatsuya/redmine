# frozen_string_literal: true
# rubocop:disable all

# Loaded by `bin/rails runner` in the checkout being measured.
require 'digest'
require 'json'
require 'nokogiri'

mode = ENV.fetch('GANTT_PERF_REQUEST_MODE')
raise 'Mode must be timing or memory' unless %w[timing memory].include?(mode)
raise 'Dedicated database required' unless ActiveRecord::Base.connection_db_config.database.include?('/gantt_performance/')

manifest = JSON.parse(File.read(ENV.fetch('GANTT_PERF_MANIFEST')))
scenario = ENV.fetch('GANTT_PERF_SCENARIO')
path = manifest.fetch("#{scenario}_path")
warmups = Integer(ENV.fetch('GANTT_PERF_WARMUPS', '5'))
iterations = mode == 'memory' ? 1 : Integer(ENV.fetch('GANTT_PERF_ITERATIONS', '15'))
raise 'Warmups and iterations must be positive' unless warmups.positive? && iterations.positive?

if mode == 'memory'
  begin
    if ENV['GANTT_PERF_MEMORY_PROFILER']
      profiler_path = File.expand_path(ENV.fetch('GANTT_PERF_MEMORY_PROFILER'))
      $LOAD_PATH.unshift(File.dirname(profiler_path))
      require profiler_path
    else
      require 'memory_profiler'
    end
  rescue LoadError => error
    abort "#{error.message}\nInstall memory_profiler and set GANTT_PERF_MEMORY_PROFILER to its absolute lib/memory_profiler.rb path (see README)."
  end
end

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! 'localhost'
session.get '/login'
token = Nokogiri::HTML(session.response.body).at_css('input[name=authenticity_token]')&.[]('value')
raise 'Login token missing' unless token
session.post('/login', :params => {
  :username => manifest.fetch('login'), :password => manifest.fetch('password'), :authenticity_token => token
})
raise 'Login failed' unless session.response.redirect? && session.request.session[:user_id]

request = lambda do
  session.get(path)
  raise "Gantt request failed: #{session.response.status}" unless session.response.status == 200
end
warmups.times {request.call}

# Parse and validate HTML outside the measured block, including memory profiling.
validation = lambda do
  doc = Nokogiri::HTML(session.response.body)
  rows = doc.css('[data-gantt-column=subjects] .gantt-pane-body > form > .gantt-row, .gantt_subjects [data-number-of-rows]')
  ids = rows.css('a.issue').filter_map {|link| link['href'][%r{/issues/(\d+)}, 1]&.to_i}.uniq.sort
  raise "Expected #{manifest['display_issue_count']} issues, got #{ids.size}" unless ids.size == manifest.fetch('display_issue_count')
  raise 'No logical rows rendered' if rows.empty?
  {'issue_count' => ids.size, 'issue_ids_sha256' => Digest::SHA256.hexdigest(ids.join(',')), 'logical_rows' => rows.size}
end

runs = Array.new(iterations) do
  if mode == 'timing'
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    request.call
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    rss = File.foreach('/proc/self/status').find {|line| line.start_with?('VmRSS:')}&.split&.[](1)&.to_i if File.exist?('/proc/self/status')
    {'request_ms' => elapsed, 'rss_kb' => rss, 'response_bytes' => session.response.body.bytesize, 'validation' => validation.call}
  else
    GC.start(:full_mark => true, :immediate_sweep => true)
    report = MemoryProfiler.report {request.call}
    result = {
      'allocated_bytes' => report.total_allocated_memsize,
      'retained_bytes' => report.total_retained_memsize,
      'allocated_objects' => report.total_allocated,
      'retained_objects' => report.total_retained,
      'allocated_memory_by_class' => report.allocated_memory_by_class.first(15),
      'retained_memory_by_class' => report.retained_memory_by_class.first(15),
      'allocated_memory_by_file' => report.allocated_memory_by_file.first(15),
      'retained_memory_by_file' => report.retained_memory_by_file.first(15)
    }
    report = nil
    result.merge('response_bytes' => session.response.body.bytesize, 'validation' => validation.call)
  end
end

result = JSON.parse(ENV.fetch('GANTT_PERF_REQUEST_METADATA')).merge(
  'mode' => mode, 'scenario' => scenario, 'path' => path,
  'ruby' => RUBY_DESCRIPTION, 'rails' => Rails.version,
  'memory_profiler' => mode == 'memory' ? MemoryProfiler::VERSION : nil,
  'warmups' => warmups, 'iterations' => iterations, 'runs' => runs
)
File.write(ENV.fetch('GANTT_PERF_REQUEST_OUTPUT'), JSON.pretty_generate(result))
puts "#{result['label']} #{mode} #{scenario}: #{runs.size} samples"
