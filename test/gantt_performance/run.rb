# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'selenium-webdriver'
require 'socket'
require 'time'

label = ARGV.fetch(0)
round = Integer(ARGV.fetch(1))
output_root = File.expand_path(ARGV.fetch(2))
app_root = File.expand_path(ARGV.fetch(3))
seed_database = File.expand_path(ARGV.fetch(4))
manifest_path = File.expand_path(ARGV.fetch(5))
warmups = Integer(ENV.fetch('GANTT_PERF_WARMUPS', '5'))
iterations = Integer(ENV.fetch('GANTT_PERF_ITERATIONS', '15'))
port = Integer(ENV.fetch('GANTT_PERF_PORT', '3100'))
base_url = "http://127.0.0.1:#{port}"
result_path = File.join(output_root, "result-#{label}-#{round}.json")
server_log_path = File.join(output_root, "server-#{label}-#{round}.log")
database_path = File.join(output_root, "database-#{label}-#{round}.sqlite3")
manifest = JSON.parse(File.read(manifest_path))

FileUtils.mkdir_p(output_root)
FileUtils.cp(seed_database, database_path)
FileUtils.rm_f(server_log_path)
server_log = File.open(server_log_path, 'w+') # rubocop:disable Style/FileOpen -- closed in ensure below
server_env = {
  'RAILS_ENV' => 'production',
  'DATABASE_URL' => "sqlite3:#{database_path}",
  'SECRET_KEY_BASE_DUMMY' => '1',
  'RUBYOPT' => "-r#{File.expand_path('frozen_clock.rb', __dir__)}"
}
server_pid = Process.spawn(
  server_env,
  'bin/rails', 'server', '-b', '0.0.0.0', '-p', port.to_s, '--log-to-stdout',
  :chdir => app_root,
  :out => server_log,
  :err => server_log
)

def wait_for_server(port, pid)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60
  loop do
    TCPSocket.open('127.0.0.1', port, :connect_timeout => 1).close
    return
  rescue SystemCallError, IOError
    raise 'Rails server exited before listening' unless Process.waitpid(pid, Process::WNOHANG).nil?
    raise 'Timed out waiting for Rails server' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    sleep 0.1
  end
end

def read_kilobytes(path, key)
  File.foreach(path) do |line|
    return Integer(line.split[1]) if line.start_with?(key)
  end
  nil
rescue Errno::ENOENT, ArgumentError
  nil
end

def process_rss_kb(pid)
  read_kilobytes("/proc/#{pid}/status", 'VmRSS:')
end

def container_memory_bytes
  Integer(File.read('/sys/fs/cgroup/memory.current').strip)
rescue Errno::ENOENT, ArgumentError
  nil
end

def git_capture(app_root, *)
  output, _, status = Open3.capture3(
    'git', '-c', "safe.directory=#{app_root}", '-C', app_root, *
  )
  return [output, status] if status.success?

  git_file = File.join(app_root, '.git')
  common_dir = ENV['GANTT_PERF_GIT_COMMON_DIR']
  return [output, status] unless common_dir && File.file?(git_file)

  admin_name = File.basename(File.read(git_file).delete_prefix('gitdir:').strip)
  git_dir = File.join(common_dir, 'worktrees', admin_name)
  output, _, status = Open3.capture3(
    'git', '-c', "safe.directory=#{app_root}",
    "--git-dir=#{git_dir}", "--work-tree=#{app_root}", *
  )
  [output, status]
end

def metric_hash(driver)
  driver.execute_cdp('Performance.getMetrics').fetch('metrics').to_h do |metric|
    [metric.fetch('name'), metric.fetch('value')]
  end
end

def metric_delta(before, after, name)
  value = after[name]
  previous = before[name]
  return nil unless value

  previous && value >= previous ? value - previous : value
end

def wait_for_chart_settle(driver)
  driver.execute_async_script(<<~JAVASCRIPT)
    const done = arguments[0]
    const deadline = performance.now() + 10000
    const check = () => {
      const lastMutation = window.__ganttPerfLastMutation || 0
      if (performance.now() - lastMutation >= 200 || performance.now() >= deadline) {
        requestAnimationFrame(() => requestAnimationFrame(() => done(performance.now())))
      } else {
        setTimeout(check, 25)
      }
    }
    check()
  JAVASCRIPT
end

COMPLETED_PATTERN =
  /Completed 200 OK in (\d+)ms \(Views: ([\d.]+)ms \| ActiveRecord: ([\d.]+)ms \((\d+) queries(?:, \d+ cached)?\) \| GC: ([\d.]+)ms\)/

def server_metrics(log_path, offset)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
  loop do
    data = File.binread(log_path)
    chunk = data.byteslice(offset..).to_s
    if (completed = chunk.scan(COMPLETED_PATTERN).last)
      return [{
        'request_ms' => completed[0].to_f,
        'view_ms' => completed[1].to_f,
        'sql_ms' => completed[2].to_f,
        'sql_queries' => completed[3].to_i,
        'gc_ms' => completed[4].to_f
      }, data.bytesize]
    end
    raise 'Timed out waiting for Rails completion log' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    sleep 0.01
  end
end

def navigation_result(driver, url, server_log_path, log_offset, server_pid)
  before_metrics = metric_hash(driver)
  driver.navigate.to(url)
  chart_ready_ms = wait_for_chart_settle(driver)
  driver.execute_cdp('HeapProfiler.collectGarbage')
  after_metrics = metric_hash(driver)
  dom = driver.execute_cdp('Memory.getDOMCounters')
  browser = driver.execute_script(<<~'JAVASCRIPT')
    const navigation = performance.getEntriesByType('navigation')[0]?.toJSON() || {}
    const fcp = performance.getEntriesByName('first-contentful-paint')[0]
    const issueIds = [...new Set(Array.from(document.querySelectorAll('a.issue'), link =>
      Number(new URL(link.href).pathname.match(/\/issues\/(\d+)/)?.[1])
    ).filter(Number.isFinite))].sort((a, b) => a - b)
    const subjects = document.querySelectorAll('.gantt_subjects [data-number-of-rows]')
    const chart = document.querySelector('.gantt-chart, table.gantt-table')
    return {
      navigation,
      fcp_ms: fcp?.startTime,
      issue_ids: issueIds,
      logical_rows: subjects.length,
      svg_paths: document.querySelectorAll('#gantt_draw_area path').length,
      body_html_characters: document.documentElement.outerHTML.length,
      chart_html_characters: chart?.outerHTML.length || 0
    }
  JAVASCRIPT
  rails, new_offset = server_metrics(server_log_path, log_offset)
  navigation = browser.fetch('navigation')
  issue_ids = browser.fetch('issue_ids')
  result = {
    'chart_ready_ms' => chart_ready_ms,
    'response_start_ms' => navigation['responseStart'],
    'response_end_ms' => navigation['responseEnd'],
    'dom_content_loaded_ms' => navigation['domContentLoadedEventEnd'],
    'load_event_end_ms' => navigation['loadEventEnd'],
    'encoded_body_bytes' => navigation['encodedBodySize'],
    'transfer_bytes' => navigation['transferSize'],
    'fcp_ms' => browser['fcp_ms'],
    'unique_issue_count' => issue_ids.size,
    'unique_issue_ids_sha256' => Digest::SHA256.hexdigest(issue_ids.join(',')),
    'logical_rows' => browser.fetch('logical_rows'),
    'svg_paths' => browser.fetch('svg_paths'),
    'body_html_characters' => browser.fetch('body_html_characters'),
    'chart_html_characters' => browser.fetch('chart_html_characters'),
    'js_heap_used_bytes' => after_metrics['JSHeapUsedSize'],
    'js_heap_total_bytes' => after_metrics['JSHeapTotalSize'],
    'documents' => dom['documents'],
    'nodes' => dom['nodes'],
    'js_event_listeners' => dom['jsEventListeners'],
    'task_duration_ms' => metric_delta(before_metrics, after_metrics, 'TaskDuration')&.*(1000),
    'script_duration_ms' => metric_delta(before_metrics, after_metrics, 'ScriptDuration')&.*(1000),
    'layout_duration_ms' => metric_delta(before_metrics, after_metrics, 'LayoutDuration')&.*(1000),
    'recalc_style_duration_ms' => metric_delta(before_metrics, after_metrics, 'RecalcStyleDuration')&.*(1000),
    'layout_count' => metric_delta(before_metrics, after_metrics, 'LayoutCount'),
    'recalc_style_count' => metric_delta(before_metrics, after_metrics, 'RecalcStyleCount'),
    'puma_rss_kb' => process_rss_kb(server_pid),
    'container_memory_bytes' => container_memory_bytes
  }.merge(rails)
  [result, new_offset]
end

memory_samples = []
sampling = true
sampler = Thread.new do
  while sampling
    memory_samples << {
      'monotonic' => Process.clock_gettime(Process::CLOCK_MONOTONIC),
      'puma_rss_kb' => process_rss_kb(server_pid),
      'container_memory_bytes' => container_memory_bytes
    }
    sleep 0.1
  end
end

driver = nil
begin
  wait_for_server(port, server_pid)
  baseline_rss_kb = process_rss_kb(server_pid)
  baseline_container_bytes = container_memory_bytes

  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = '/usr/bin/chromium'
  %w[
    --headless=new
    --no-sandbox
    --disable-dev-shm-usage
    --disable-background-networking
    --disable-default-apps
    --disable-extensions
    --disable-features=BackForwardCache
    --disable-sync
    --no-first-run
    --window-size=1440,1200
  ].each {|argument| options.add_argument(argument)}
  service = Selenium::WebDriver::Service.chrome(:path => '/usr/bin/chromedriver')
  driver = Selenium::WebDriver.for(:chrome, :options => options, :service => service)
  driver.manage.timeouts.page_load = 120
  driver.manage.timeouts.script_timeout = 30
  driver.execute_cdp('Performance.enable')
  driver.execute_cdp('Page.addScriptToEvaluateOnNewDocument', :source => <<~JAVASCRIPT)
    window.__ganttPerfLastMutation = performance.now()
    new MutationObserver(() => { window.__ganttPerfLastMutation = performance.now() })
      .observe(document, {subtree: true, childList: true, attributes: true, characterData: true})
  JAVASCRIPT

  driver.navigate.to("#{base_url}/login")
  driver.find_element(:id, 'username').send_keys(manifest.fetch('login'))
  driver.find_element(:id, 'password').send_keys(manifest.fetch('password'))
  driver.find_element(:css, 'input[name=login]').click
  Selenium::WebDriver::Wait.new(:timeout => 30).until { !driver.current_url.include?('/login') }
  driver.navigate.to(base_url)

  scenarios = {'normal' => manifest.fetch('normal_path'), 'heavy' => manifest.fetch('heavy_path')}
  results = {}
  server_log_offset = File.size(server_log_path)

  scenarios.each do |name, path|
    warmups.times do
      _, server_log_offset = navigation_result(
        driver, "#{base_url}#{path}", server_log_path, server_log_offset, server_pid
      )
    end

    measured_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    runs = Array.new(iterations) do |index|
      result, server_log_offset = navigation_result(
        driver, "#{base_url}#{path}", server_log_path, server_log_offset, server_pid
      )
      puts "#{label} round=#{round} #{name} run=#{index + 1}/#{iterations} " \
           "ready=#{result['chart_ready_ms'].round(1)}ms request=#{result['request_ms']}ms " \
           "rss=#{result['puma_rss_kb']}KB"
      result
    end
    measured_finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    results[name] = {
      'path' => path,
      'warmups' => warmups,
      'iterations' => iterations,
      'measured_started_at' => measured_started_at,
      'measured_finished_at' => measured_finished_at,
      'runs' => runs
    }
  end

  commit, commit_status = git_capture(app_root, 'rev-parse', 'HEAD')
  raise "Unable to read the Git revision for #{app_root}" unless commit_status.success?

  status, status_status = git_capture(app_root, 'status', '--porcelain')
  raise "Unable to read the Git status for #{app_root}" unless status_status.success?

  output = {
    'label' => label,
    'round' => round,
    'commit' => commit.strip,
    'dirty' => !status.strip.empty?,
    'app_root' => app_root,
    'recorded_at' => Time.now.iso8601,
    'ruby' => RUBY_DESCRIPTION,
    'bundle_lock_sha256' => Digest::SHA256.file(File.join(app_root, 'Gemfile.lock')).hexdigest,
    'selenium' => Selenium::WebDriver::VERSION,
    'chrome' => driver.capabilities.browser_version,
    'platform' => driver.capabilities.platform_name,
    'viewport' => driver.execute_script('return {width: window.innerWidth, height: window.innerHeight}'),
    'warmups' => warmups,
    'iterations' => iterations,
    'baseline_puma_rss_kb' => baseline_rss_kb,
    'baseline_container_memory_bytes' => baseline_container_bytes,
    'scenarios' => results,
    'memory_samples' => memory_samples
  }
  File.write(result_path, JSON.pretty_generate(output))
  puts "wrote #{result_path}"
ensure
  driver&.quit
  sampling = false
  sampler.join(2)
  if server_pid && server_pid > 1
    begin
      Process.kill('TERM', server_pid)
    rescue Errno::ESRCH
      nil
    end
    begin
      Process.wait(server_pid)
    rescue Errno::ECHILD
      nil
    end
  end
  server_log.close
end
