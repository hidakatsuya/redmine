# frozen_string_literal: true
# rubocop:disable all

require 'json'

root = File.expand_path(ARGV.fetch(0))
index = JSON.parse(File.read(File.join(root, 'index.json')))
records = index.fetch('records').map {|name| JSON.parse(File.read(File.join(root, name)))}
raise 'No request records' if records.empty?
shared = %w[ruby rails bundle_sha256 seed_sha256 manifest_sha256]
shared.each {|key| raise "Inconsistent #{key}" unless records.map {|r| r.fetch(key)}.uniq.one?}
records.group_by {|r| r.fetch('mode')}.each do |mode, group|
  raise "Inconsistent #{mode} warmups or iterations" unless group.map {|r| r.values_at('warmups', 'iterations', 'memory_profiler')}.uniq.one?
end

def median(values)
  values = values.compact.sort
  return nil if values.empty?
  middle = values.size / 2
  values.size.odd? ? values[middle] : (values[middle - 1] + values[middle]) / 2.0
end

summary = {'environment' => records.first.slice(*shared), 'scenarios' => {}}
report = ['# Gantt Rails request comparison', '',
          'Timing: uninstrumented, complete in-process Rack requests; excludes browser, network and Puma.',
          'Memory: separate memory_profiler processes; profiled timings and RSS are not reported.', '',
          "- before: `#{records.find {|r| r['label'] == 'before'}&.fetch('revision')}`",
          "- after: `#{records.find {|r| r['label'] == 'after'}&.fetch('revision')}`", '']
records.group_by {|r| r.fetch('scenario')}.each do |scenario, group|
  signatures = group.flat_map {|r| r.fetch('runs').map {|run| run.fetch('validation')}}.uniq
  raise "Rendered workload differs for #{scenario}" unless signatures.one?
  section = {'validation' => signatures.first, 'modes' => {}}
  report.concat(["## #{scenario}", '', '| Metric (median) | Before | After | Change |', '| --- | ---: | ---: | ---: |'])
  group.group_by {|r| r.fetch('mode')}.each do |mode, samples|
    labels = samples.group_by {|r| r.fetch('label')}
    raise "Missing comparison side for #{scenario}/#{mode}" unless labels.keys.sort == %w[after before]
    raise 'Round counts differ' unless labels.values.map {|rs| rs.map {|r| r['round']}.sort}.uniq.one?
    metrics = mode == 'timing' ? %w[request_ms rss_kb response_bytes] : %w[allocated_bytes retained_bytes allocated_objects retained_objects]
    data = {'metrics' => {}, 'rounds' => {}, 'memory_profiler' => samples.first['memory_profiler']}
    metrics.each do |metric|
      pair = %w[before after].map {|label| median(labels[label].flat_map {|r| r['runs'].map {|run| run[metric]}})}
      delta = pair.all? && pair.first != 0 ? (pair.last.to_f / pair.first - 1) * 100 : nil
      data['metrics'][metric] = {'before' => pair.first, 'after' => pair.last, 'change_percent' => delta}
      display = pair.map {|value| value.nil? ? '-' : format('%.3f', value)}
      report << "| #{metric} | #{display.first} | #{display.last} | #{delta ? format('%+.2f%%', delta) : '-'} |"
    end
    %w[before after].each do |label|
      data['rounds'][label] = labels[label].to_h do |r|
        [r['round'], metrics.to_h {|metric| [metric, median(r['runs'].map {|run| run[metric]})]}]
      end
    end
    section['modes'][mode] = data
  end
  summary['scenarios'][scenario] = section
  report << ''
end
report.concat(['## Interpretation', '',
  'Keep every sample and examine individual round medians in summary.json; a small difference alone does not establish a regression.',
  'Retained bytes are allocations from the measured request still reachable after the profiler GC, not total process memory.',
  'Use the original browser benchmark for page-ready time and uninstrumented Puma RSS.', ''])
File.write(File.join(root, 'summary.json'), JSON.pretty_generate(summary))
File.write(File.join(root, 'report.md'), report.join("\n"))
puts report.join("\n")
