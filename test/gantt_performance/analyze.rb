# frozen_string_literal: true
# rubocop:disable all

require 'json'

root = File.expand_path(ARGV.fetch(0))
labels = %w[before after]
rounds = [1, 2]
scenarios = %w[normal heavy]
metrics = %w[
  chart_ready_ms request_ms view_ms sql_ms sql_queries gc_ms
  response_start_ms response_end_ms dom_content_loaded_ms load_event_end_ms fcp_ms
  encoded_body_bytes transfer_bytes body_html_characters chart_html_characters
  js_heap_used_bytes js_heap_total_bytes documents nodes js_event_listeners
  task_duration_ms script_duration_ms layout_duration_ms recalc_style_duration_ms
  layout_count recalc_style_count puma_rss_kb container_memory_bytes
]

def percentile(values, fraction)
  sorted = values.compact.sort
  return nil if sorted.empty?

  sorted.fetch((fraction * (sorted.length - 1)).ceil)
end

def median(values)
  sorted = values.compact.sort
  return nil if sorted.empty?

  middle = sorted.length / 2
  sorted.length.odd? ? sorted.fetch(middle) : (sorted.fetch(middle - 1) + sorted.fetch(middle)) / 2.0
end

def stats(values)
  compact = values.compact
  {'count' => compact.size, 'median' => median(compact), 'p95' => percentile(compact, 0.95),
   'min' => compact.min, 'max' => compact.max}
end

def ratio(after, before)
  after && before && before != 0 ? after.to_f / before : nil
end

def format_value(value)
  return '-' if value.nil?
  return value.to_s if value.is_a?(Integer)

  format('%.2f', value)
end

data = labels.to_h do |label|
  values = rounds.to_h do |round|
    path = File.join(root, "result-#{label}-#{round}.json")
    [round, JSON.parse(File.read(path))]
  end
  [label, values]
end

summary = {
  'environment' => labels.to_h do |label|
    sample = data.fetch(label).fetch(1)
    [label, sample.slice('commit', 'dirty', 'app_root', 'ruby', 'selenium', 'chrome', 'platform', 'viewport',
                         'bundle_lock_sha256', 'warmups', 'iterations')]
  end,
  'scenarios' => {}
}

scenarios.each do |scenario|
  scenario_summary = {'metrics' => {}, 'validation' => {}, 'memory_peaks' => {}}
  metrics.each do |metric|
    before_values = rounds.flat_map do |round|
      data.fetch('before').fetch(round).fetch('scenarios').fetch(scenario).fetch('runs').map {|run| run[metric]}
    end
    after_values = rounds.flat_map do |round|
      data.fetch('after').fetch(round).fetch('scenarios').fetch(scenario).fetch('runs').map {|run| run[metric]}
    end
    before_stats = stats(before_values)
    after_stats = stats(after_values)
    scenario_summary['metrics'][metric] = {
      'before' => before_stats,
      'after' => after_stats,
      'median_ratio' => ratio(after_stats['median'], before_stats['median']),
      'p95_ratio' => ratio(after_stats['p95'], before_stats['p95'])
    }
  end

  validations = labels.flat_map do |label|
    rounds.flat_map do |round|
      data.fetch(label).fetch(round).fetch('scenarios').fetch(scenario).fetch('runs').map do |run|
        run.slice('unique_issue_count', 'unique_issue_ids_sha256', 'logical_rows', 'svg_paths')
      end
    end
  end.uniq
  scenario_summary['validation'] = {'consistent' => validations.one?, 'values' => validations}

  labels.each do |label|
    scenario_summary['memory_peaks'][label] = rounds.to_h do |round|
      record = data.fetch(label).fetch(round)
      window = record.fetch('scenarios').fetch(scenario)
      samples = record.fetch('memory_samples').select do |sample|
        sample.fetch('monotonic').between?(window.fetch('measured_started_at'), window.fetch('measured_finished_at'))
      end
      [round.to_s, {
        'puma_rss_kb' => samples.filter_map {|sample| sample['puma_rss_kb']}.max,
        'container_memory_bytes' => samples.filter_map {|sample| sample['container_memory_bytes']}.max
      }]
    end
  end
  summary['scenarios'][scenario] = scenario_summary
end

File.write(File.join(root, 'summary.json'), JSON.pretty_generate(summary))

report = [
  '# Gantt performance comparison',
  '',
  "- before: `#{summary.dig('environment', 'before', 'commit')}`" \
    "#{' (dirty)' if summary.dig('environment', 'before', 'dirty')}",
  "- after: `#{summary.dig('environment', 'after', 'commit')}`" \
    "#{' (dirty)' if summary.dig('environment', 'after', 'dirty')}",
  "- Chromium: #{summary.dig('environment', 'after', 'chrome')}",
  "- bundle lock: `#{summary.dig('environment', 'after', 'bundle_lock_sha256')}`",
  "- samples: #{summary.dig('environment', 'after', 'warmups')} warmups + " \
    "#{summary.dig('environment', 'after', 'iterations')} measured per scenario and round",
  ''
]

selected_metrics = %w[
  chart_ready_ms request_ms view_ms fcp_ms task_duration_ms layout_duration_ms
  recalc_style_duration_ms js_heap_used_bytes nodes js_event_listeners
  chart_html_characters puma_rss_kb
]
summary.fetch('scenarios').each do |scenario, values|
  report.push(
    "## #{scenario}",
    '',
    "Validation consistent: **#{values.dig('validation', 'consistent')}**",
    '',
    '| Metric | Before median | After median | Delta | Before p95 | After p95 | Delta |',
    '| --- | ---: | ---: | ---: | ---: | ---: | ---: |'
  )
  selected_metrics.each do |metric|
    value = values.fetch('metrics').fetch(metric)
    median_delta = value['median_ratio'] ? (value['median_ratio'] - 1) * 100 : nil
    p95_delta = value['p95_ratio'] ? (value['p95_ratio'] - 1) * 100 : nil
    report << "| #{metric} | #{format_value(value.dig('before', 'median'))} | " \
              "#{format_value(value.dig('after', 'median'))} | " \
              "#{median_delta ? format('%+.1f%%', median_delta) : '-'} | " \
              "#{format_value(value.dig('before', 'p95'))} | " \
              "#{format_value(value.dig('after', 'p95'))} | " \
              "#{p95_delta ? format('%+.1f%%', p95_delta) : '-'} |"
  end
  report << ''
end

report.push(
  '## Interpretation',
  '',
  '- Treat the full uninstrumented request and browser metrics as the canonical comparison.',
  '- Investigate large median/p95 disagreement instead of excluding individual runs.',
  '- Memory, DOM, and HTML growth can reject a change even when request time is unchanged.',
  '- Results are comparable only when the database, assets, bundle, Redmined image, and browser match.',
  ''
)
File.write(File.join(root, 'report.md'), report.join("\n"))
puts report.join("\n")
