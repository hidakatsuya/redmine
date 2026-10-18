# frozen_string_literal: true

# Start from a copy of the visual harness seed, never a development database.
require 'json'
require Rails.root.join('test/object_helpers')
include ObjectHelpers

database = ActiveRecord::Base.connection_db_config.database
raise 'Dedicated database required' unless database.include?('/gantt_performance/')

User.current = User.find(1)
Setting.gantt_items_limit = '1000'
scenarios = []
[100, 500].each do |count|
  project = Project.generate!(
    :name => "Resize benchmark #{count}", :identifier => "resize-benchmark-#{count}",
    :enabled_module_names => %w[issue_tracking gantt], :tracker_ids => [1]
  )
  issues = Array.new(count) do |index|
    Issue.generate!(
      :project => project, :author_id => 1, :tracker_id => 1,
      :subject => format('Resize task %03d', index),
      :start_date => Date.new(2026, 8, 1) + index % 15,
      :due_date => Date.new(2026, 9, 20) + index % 10,
      :done_ratio => index % 100
    )
  end
  issues.each_cons(2) do |from, to|
    IssueRelation.create!(:issue_from => from, :issue_to => to, :relation_type => 'blocks')
  end
  modes = count == 100 ? [[true, true]] : [[true, false], [false, true], [true, true]]
  modes.each do |relations, progress|
    params = {
      :set_filter => '1', :year => '2026', :month => '6', :months => '6', :zoom => '3',
      :f => ['project_id'], :op => {'project_id' => '='}, :v => {'project_id' => [project.id.to_s]},
      :draw_relations => relations ? '1' : '0', :draw_progress_line => progress ? '1' : '0',
      :draw_selected_columns => '1', :c => %w[subject status priority assigned_to]
    }
    scenarios << {
      :id => "#{count}-#{relations ? 'relations' : 'no-relations'}-#{progress ? 'progress' : 'no-progress'}",
      :path => "/issues/gantt?#{params.to_query}", :issue_ids => issues.map(&:id),
      :relations => relations ? count - 1 : 0
    }
  end
end
File.write(ENV.fetch('GANTT_RESIZE_MANIFEST'), JSON.pretty_generate(scenarios))
puts "Prepared #{scenarios.length} resize scenarios"
