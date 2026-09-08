# frozen_string_literal: true
# rubocop:disable all

require 'selenium-webdriver'
require 'json'
require 'base64'
require 'fileutils'
require 'socket'
require 'net/http'

ROOT = File.expand_path('../..', __dir__)
OUTPUT = File.join(ROOT, 'tmp/gantt_visual')
LABEL = ARGV.fetch(0)
raise ArgumentError, 'Use expected or actual' unless %w(expected actual).include?(LABEL)
CHECKOUT = LABEL == 'expected' ? File.join(ROOT, 'tmp/gantt_visual_baseline') : ROOT
PORT = LABEL == 'expected' ? 3101 : 3102
ORIGIN = "http://127.0.0.1:#{PORT}"
MANIFEST = JSON.parse(File.read(File.join(OUTPUT, 'manifest.json')))

def ready(driver)
  Selenium::WebDriver::Wait.new(timeout: 30).until {driver.find_elements(:css, '#gantt_area').any?}
  driver.execute_async_script(<<~'JS')
    const done = arguments[0];
    document.fonts.ready.then(() => Promise.all(Array.from(document.images).map(i =>
      i.complete ? Promise.resolve() : new Promise(r => {i.onload = r; i.onerror = r}))))
      .then(() => requestAnimationFrame(() => requestAnimationFrame(() => requestAnimationFrame(done))));
  JS
end

def snapshot(driver)
  driver.execute_script(<<~'JS')
    const modern = !!document.querySelector('.gantt__rows');
    const nodes = Array.from(document.querySelectorAll(modern ? '.gantt__row' : '.gantt_subjects > form > div, .gantt_subjects > div'));
    let project = null;
    const rows = nodes.map(e => {
      const key = modern ? e.dataset.rowKey : (e.dataset.collapseExpand ? JSON.parse(e.dataset.collapseExpand).obj_id : null);
      if (!key) return null;
      let kind, id;
      if (modern) {
        kind = e.dataset.kind;
        id = Number(key.match(/(\d+)$/)[1]);
      } else {
        [kind, id] = key.split('-'); id = Number(id);
      }
      if (kind === 'project') project = id;
      return {kind, id, project, visible: !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length),
              top: e.getBoundingClientRect().top};
    }).filter(Boolean);
    return {rows, title: document.title, url: location.href,
      warning: !!document.querySelector('.warning'),
      paths: document.querySelectorAll('#gantt_draw_area path').length,
      today: !!document.querySelector('#today_line'),
      selected: Array.from(document.querySelectorAll('input[name="ids[]"]:checked')).map(e => Number(e.value)),
      menu: !!document.querySelector('#context-menu a.icon-edit'),
      printing: !!document.querySelector('.gantt.is-printing'),
      subjectWidth: document.querySelector(modern ? '.gantt__subject-header' : '.gantt_subjects_column')?.getBoundingClientRect().width,
      columnWidth: document.querySelector(modern ? '.gantt__column-header' : '.gantt_selected_column')?.getBoundingClientRect().width,
      errors: document.querySelector('#errorExplanation')?.textContent || null};
  JS
end

def print_pdf(driver, filename)
  result = driver.execute_cdp('Page.printToPDF', paperWidth: 11.69, paperHeight: 8.27,
                             marginTop: 0.4, marginBottom: 0.4, marginLeft: 0.4, marginRight: 0.4,
                             printBackground: true, displayHeaderFooter: false)
  File.binwrite(filename, Base64.decode64(result.fetch('data')))
end

def capture(driver, directory, name, print: true)
  ready(driver)
  driver.save_screenshot(File.join(directory, "#{name}.png"))
  state = snapshot(driver)
  File.write(File.join(directory, "#{name}.json"), JSON.pretty_generate(state))
  print_pdf(driver, File.join(directory, "#{name}-print.pdf")) if print
  state
end

def checkbox(driver, id, checked)
  fieldset = driver.find_element(:css, '#options')
  fieldset.find_element(:css, 'legend').click if fieldset.attribute('class').include?('collapsed')
  box = driver.find_element(:id, id)
  box.click if box.selected? != checked
end

def perform(driver, action)
  modern = driver.find_elements(:css, '.gantt__rows').any?
  before = snapshot(driver)
  case action
  when 'progress-off', 'progress-on'
    checkbox(driver, 'draw_progress_line', action.end_with?('-on'))
  when 'columns-off', 'columns-on'
    checkbox(driver, 'draw_selected_columns', action.end_with?('-on'))
  when 'scroll', 'scroll-to-bars', 'scroll-to-ends'
    left = { 'scroll' => 250, 'scroll-to-bars' => 700, 'scroll-to-ends' => 1400 }.fetch(action)
    driver.execute_script("document.querySelector(arguments[0]).scrollLeft = arguments[1]", modern ? '.gantt__viewport' : '#gantt_area', left)
  when 'narrow'
    driver.execute_cdp('Emulation.setDeviceMetricsOverride', width: 1000, height: 1000, deviceScaleFactor: 1, mobile: false)
  when 'resize-subject', 'resize-column'
    selector = if modern
                 action == 'resize-subject' ? '.gantt__splitter' : '.gantt__column-resizer'
               else
                 action == 'resize-subject' ? "[data-gantt--column-column-value=subjects] .ui-resizable-e" : 'td.gantt_selected_column .ui-resizable-e'
               end
    element = driver.find_element(:css, selector)
    driver.action.move_to(element).click_and_hold.move_by(60, 0).release.perform
  when /\A(collapse|expand)-(project|version|parent)\z/
    kind = Regexp.last_match(2)
    id = case kind
         when 'project' then MANIFEST['projects'][driver.current_url.include?("#{MANIFEST['queries']['hierarchy']}") ? 'hierarchy' : 'basic']
         when 'version' then MANIFEST['versions']['basic']
         when 'parent' then MANIFEST['issues']['parent']
         end
    selector = if modern
                 kind == 'project' ? '.gantt__row--project .gantt__expander' :
                   (kind == 'version' ? '.gantt__row--version .gantt__expander' : "#issue-#{id} .gantt__expander")
               else
                 kind == 'project' ? '.gantt_subjects .project-name .expander' :
                   (kind == 'version' ? '.gantt_subjects .version-name .expander' : "#issue-#{id} .expander")
               end
    driver.find_element(:css, selector).click
  when 'next', 'previous'
    driver.find_element(:css, ".pagination .#{action} a").click
  when 'zoom-in'
    driver.find_element(:css, 'a.icon-zoom-in').click
  when 'reload'
    driver.navigate.refresh
  when 'filter-all'
    Selenium::WebDriver::Support::Select.new(driver.find_element(:id, 'operators_status_id')).select_by(:value, '*')
    driver.find_element(:css, '#query_form_with_buttons a.icon-checked').click
  when 'tooltip', 'subject-menu', 'bar-menu', 'multi-select'
    id = MANIFEST['issues']['basic-open']
    subject = driver.find_element(:css, "#issue-#{id}")
    bar = driver.find_element(:css, modern ? ".gantt__bar-hitbox[data-row-key='issue-#{id}']" : "#gantt_area .tooltip[data-collapse-expand='issue-#{id}']")
    driver.find_element(:css, 'h2').click
    case action
    when 'tooltip'
      driver.action.move_to(bar).perform
      Selenium::WebDriver::Wait.new(timeout: 10).until {bar.find_element(:css, '.tip').displayed?}
    when 'subject-menu', 'bar-menu'
      driver.action.context_click(action == 'subject-menu' ? subject : bar).perform
      Selenium::WebDriver::Wait.new(timeout: 10).until {driver.find_elements(:css, '#context-menu a.icon-edit').any?(&:displayed?)}
    when 'multi-select'
      other = driver.find_element(:css, "#issue-#{MANIFEST['issues']['basic-long']}")
      driver.action.click(subject).key_down(:control).click(other).key_up(:control).perform
    end
  when 'print-return'
    print_pdf(driver, File.join(OUTPUT, 'print-return-probe.pdf'))
    raise 'Print state left behind' if driver.find_elements(:css, '.gantt.is-printing').any?
  else
    raise "Unknown action: #{action}"
  end
  ready(driver)
  after = snapshot(driver)
  if action.start_with?('collapse-')
    raise 'Collapse did not hide descendants' unless after['rows'].count {|r| r['visible']} < before['rows'].count {|r| r['visible']}
  elsif action.start_with?('expand-')
    raise 'Expand did not restore descendants' unless after['rows'].all? {|r| r['visible']}
  elsif action.start_with?('resize-')
    field = action == 'resize-subject' ? 'subjectWidth' : 'columnWidth'
    raise 'Resize did not increase width' unless after[field] > before[field]
  elsif action == 'multi-select'
    raise 'Incorrect selected issues' unless after['selected'].uniq.sort == [MANIFEST['issues']['basic-open'], MANIFEST['issues']['basic-long']].sort
  end
end

def export_files(driver, directory, name, result)
  %w(pdf png).each do |format|
    uri = URI(driver.current_url.sub('/gantt?', "/gantt.#{format}?"))
    request = Net::HTTP::Get.new(uri)
    request['Cookie'] = driver.manage.all_cookies.map {|cookie| "#{cookie[:name]}=#{cookie[:value]}"}.join('; ')
    response = Net::HTTP.start(uri.host, uri.port, read_timeout: 120) {|http| http.request(request)}
    File.binwrite(File.join(directory, "#{name}.#{format}"), response.body)
    magic = format == 'pdf' ? response.body.start_with?('%PDF-') : response.body.b.start_with?("\x89PNG".b)
    result['exports']["#{name}.#{format}"] = { 'status' => response.code.to_i, 'type' => response['content-type'],
                                           'bytes' => response.body.bytesize, 'valid_header' => magic, 'url' => uri.to_s }
  end
end

cases = JSON.parse(File.read(File.join(OUTPUT, 'cases.json')))
cases.select! {|c| c['id'].match?(Regexp.new(ARGV[1]))} if ARGV[1]
cases.each do |test_case|
  directory = File.join(OUTPUT, LABEL, test_case['id'])
  FileUtils.mkdir_p(directory)
  Dir[File.join(directory, '*.{png,pdf,json}')].each {|path| File.delete(path)}
  db = File.join(OUTPUT, "#{LABEL}.sqlite3")
  FileUtils.cp(File.join(OUTPUT, 'seed.sqlite3'), db)
  log = File.open(File.join(directory, 'server.log'), 'w')
  env = { 'RAILS_ENV' => 'production', 'DATABASE_URL' => "sqlite3:#{db}", 'SECRET_KEY_BASE_DUMMY' => '1',
         'BUNDLE_GEMFILE' => File.join(ROOT, 'Gemfile'), 'RUBYOPT' => "-r#{ROOT}/test/gantt_visual/frozen_clock.rb" }
  env['GANTT_VISUAL_LIMIT'] = test_case['limit'].to_s if test_case['limit']
  pid = Process.spawn(env, 'bin/rails', 'server', '-b', '127.0.0.1', '-p', PORT.to_s,
                      '-P', File.join(OUTPUT, "#{LABEL}.pid"), chdir: CHECKOUT, out: log, err: log)
  driver = nil
  result = { 'id' => test_case['id'], 'states' => {}, 'exports' => {} }
  begin
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 40
    loop do
      begin
        TCPSocket.open('127.0.0.1', PORT).close
        break
      rescue Errno::ECONNREFUSED
        raise 'Server timeout' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.1
      end
    end
    options = Selenium::WebDriver::Chrome::Options.new
    options.binary = '/usr/bin/chromium'
    %w[--headless=new --no-sandbox --disable-dev-shm-usage --force-device-scale-factor=1].each {|arg| options.add_argument(arg)}
    driver = Selenium::WebDriver.for(:chrome, options: options,
                                     service: Selenium::WebDriver::Service.chrome(path: '/usr/bin/chromedriver'))
    driver.execute_cdp('Emulation.setDeviceMetricsOverride', width: test_case['viewport'][0], height: test_case['viewport'][1], deviceScaleFactor: 1, mobile: false)
    if test_case['user'] != 'anonymous'
      driver.navigate.to("#{ORIGIN}/login")
      driver.find_element(:id, 'username').send_keys(test_case['user'])
      driver.find_element(:id, 'password').send_keys('visual-password')
      driver.find_element(:css, 'input[name=login]').click
      Selenium::WebDriver::Wait.new(timeout: 20).until {!driver.current_url.include?('/login')}
    end
    driver.navigate.to(ORIGIN + test_case['path'])
    result['states']['screen'] = capture(driver, directory, 'screen', print: test_case['print'])
    ids = result['states']['screen']['rows'].select {|row| row['kind'] == 'issue'}.map {|row| row['id']}
    result['issue_set_matches'] = ids.sort == test_case['expected_issue_ids'].sort
    result['issue_order_matches'] = !test_case['expected_issue_order'] || ids == test_case['expected_issue_order']
    result['browser'] = driver.capabilities.browser_version
    export_files(driver, directory, 'export', result) if test_case['exports']
    test_case['actions'].each do |action|
      perform(driver, action)
      result['states'][action] = capture(driver, directory, action, print: test_case['print'])
    end
    export_files(driver, directory, 'final-export', result) if test_case['group'] == 'G14'
    if test_case['group'] == 'G17'
      [700, 1400, 2100].each do |top|
        driver.execute_script('window.scrollTo(0, arguments[0])', top)
        driver.save_screenshot(File.join(directory, "scroll-#{top}.png"))
      end
    end
  rescue StandardError => error
    result['error'] = "#{error.class}: #{error.message}"
    driver&.save_screenshot(File.join(directory, 'failure.png')) rescue nil
  ensure
    begin
      driver&.quit
    rescue StandardError => error
      result['error'] ||= "Browser cleanup failed: #{error.message}"
    end
    Process.kill('TERM', pid) rescue nil
    Process.wait(pid) rescue nil
    log.close
    File.write(File.join(directory, 'result.json'), JSON.pretty_generate(result))
  end
  puts "#{LABEL} #{test_case['id']}: #{result['error'] || (result['issue_set_matches'] && result['issue_order_matches'] ? 'captured' : 'semantic mismatch')}"
  $stdout.flush
end

# rubocop:enable all
