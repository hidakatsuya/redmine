# frozen_string_literal: true
# rubocop:disable all

require 'active_record/fixtures'
require 'json'

PREFIX = 'gantt-perf'
PROJECT_COUNT = 20
VERSIONS_PER_PROJECT = 3
ISSUES_PER_PROJECT = 100
DISPLAY_ISSUES_PER_PROJECT = 20
REFERENCE_DATE = Date.new(2026, 8, 1)
LOGIN = 'gantt-perf-admin'
PASSWORD = 'gantt-perf-password'
RELATIONS = [[0, 3, 'precedes'], [4, 7, 'blocks'], [8, 12, 'precedes'], [13, 18, 'blocks']].freeze

database = ActiveRecord::Base.connection_db_config.database
raise 'Dedicated database required' unless database.include?('/gantt_performance/')

fixtures = Dir[Rails.root.join('test/fixtures/*.yml')].map {|path| File.basename(path, '.yml')}
ActiveRecord::FixtureSet.create_fixtures(Rails.root.join('test/fixtures'), fixtures)

User.current = User.find(1)
Setting.default_language = 'en'
Setting.login_required = '0'
Setting.gravatar_enabled = '0'
Setting.non_working_week_days = %w[6 7]
Setting.gantt_items_limit = '500'
Setting.gantt_months_limit = '24'
Setting.issue_done_ratio = 'issue_field'
Setting.cross_project_issue_relations = '1'

admin = User.find(1)
admin.update!(
  :login => LOGIN,
  :password => PASSWORD,
  :password_confirmation => PASSWORD,
  :must_change_passwd => false,
  :admin => true,
  :language => 'en'
)
admin.pref.update!(:time_zone => 'UTC')

open_status = IssueStatus.where(:is_closed => false).order(:position).first!
closed_status = IssueStatus.where(:is_closed => true).order(:position).first!
priorities = IssuePriority.active.order(:position).to_a
background_tracker = Tracker.order(:position).first!
display_tracker = Tracker.create!(
  :name => 'Gantt performance',
  :default_status => open_status,
  :position => Tracker.maximum(:position).to_i + 1
)
manager_role = Role.find_by(:name => 'Manager') || Role.givable.first!

roots = Array.new(2) do |root_index|
  Project.create!(
    :name => "Gantt Perf Root #{root_index + 1}",
    :identifier => "#{PREFIX}-root-#{root_index + 1}",
    :is_public => true,
    :enabled_module_names => %w[issue_tracking gantt]
  )
end

children = roots.flat_map.with_index do |root, root_index|
  Array.new(3) do |child_index|
    Project.create!(
      :name => "Gantt Perf Child #{root_index + 1}-#{child_index + 1}",
      :identifier => "#{PREFIX}-child-#{root_index + 1}-#{child_index + 1}",
      :parent => root,
      :is_public => true,
      :enabled_module_names => %w[issue_tracking gantt]
    )
  end
end

grandchildren = children.flat_map.with_index do |child, child_index|
  Array.new(2) do |grandchild_index|
    Project.create!(
      :name => "Gantt Perf Grandchild #{child_index + 1}-#{grandchild_index + 1}",
      :identifier => "#{PREFIX}-grandchild-#{child_index + 1}-#{grandchild_index + 1}",
      :parent => child,
      :is_public => true,
      :enabled_module_names => %w[issue_tracking gantt]
    )
  end
end

projects = roots + children + grandchildren
raise "Unexpected project count: #{projects.size}" unless projects.size == PROJECT_COUNT

display_issue_ids = []
projects.each_with_index do |project, project_index|
  project.trackers = [display_tracker, background_tracker].uniq
  Member.create!(:project => project, :principal => admin, :roles => [manager_role])

  versions = Array.new(VERSIONS_PER_PROJECT) do |version_index|
    Version.create!(
      :project => project,
      :name => "Gantt Perf Version #{project_index + 1}-#{version_index + 1}",
      :status => 'open',
      :sharing => 'none',
      :effective_date => REFERENCE_DATE + (version_index * 60) - 30
    )
  end

  displayed = []
  DISPLAY_ISSUES_PER_PROJECT.times do |issue_index|
    chain_start = (issue_index / 3) * 3
    parent = if issue_index % 3 == 1
               displayed[chain_start]
             elsif issue_index % 3 == 2
               displayed[chain_start + 1]
             end
    start_date = REFERENCE_DATE - 45 + ((project_index * 7 + issue_index * 5) % 150)
    version = versions[(issue_index / 3) % VERSIONS_PER_PROJECT] if issue_index < 15
    status = (issue_index / 3) % 4 == 0 ? closed_status : open_status
    issue = Issue.create!(
      :project => project,
      :tracker => display_tracker,
      :status => status,
      :priority => priorities[(project_index + issue_index) % priorities.size],
      :author => admin,
      :assigned_to => issue_index.even? ? admin : nil,
      :subject => format('[Gantt Perf] P%02d Issue %03d', project_index + 1, issue_index + 1),
      :start_date => start_date,
      :due_date => start_date + 7 + (issue_index % 21),
      :done_ratio => status.is_closed? ? 100 : (issue_index % 6) * 20,
      :fixed_version => version,
      :parent_issue_id => parent&.id
    )
    displayed << issue
    display_issue_ids << issue.id
  end

  (ISSUES_PER_PROJECT - DISPLAY_ISSUES_PER_PROJECT).times do |background_index|
    start_date = REFERENCE_DATE - 120 + ((project_index * 13 + background_index * 3) % 360)
    Issue.create!(
      :project => project,
      :tracker => background_tracker,
      :status => open_status,
      :priority => priorities[(project_index + background_index) % priorities.size],
      :author => admin,
      :subject => format('[Gantt Perf Background] P%02d Issue %03d', project_index + 1, background_index + 1),
      :start_date => start_date,
      :due_date => start_date + 3 + (background_index % 30),
      :done_ratio => (background_index % 5) * 20
    )
  end

  RELATIONS.each do |from, to, type|
    IssueRelation.create!(
      :issue_from => displayed.fetch(from),
      :issue_to => displayed.fetch(to),
      :relation_type => type
    )
  end
end

normal_query = IssueQuery.new(
  :name => 'Gantt Performance - Normal',
  :user => admin,
  :visibility => IssueQuery::VISIBILITY_PUBLIC,
  :filters => {'tracker_id' => {:operator => '=', :values => [display_tracker.id.to_s]}},
  :column_names => []
)
normal_query.draw_relations = '1'
normal_query.draw_progress_line = '0'
normal_query.draw_selected_columns = '0'
normal_query.save!

heavy_query = IssueQuery.new(
  :name => 'Gantt Performance - Heavy',
  :user => admin,
  :visibility => IssueQuery::VISIBILITY_PUBLIC,
  :filters => {'tracker_id' => {:operator => '=', :values => [display_tracker.id.to_s]}},
  :column_names => %w[status priority assigned_to]
)
heavy_query.draw_relations = '1'
heavy_query.draw_progress_line = '1'
heavy_query.draw_selected_columns = '1'
heavy_query.save!

reference_start = REFERENCE_DATE << 2
heavy_start = REFERENCE_DATE << 6
manifest = {
  :reference_date => REFERENCE_DATE.iso8601,
  :login => LOGIN,
  :password => PASSWORD,
  :project_count => projects.count,
  :version_count => Version.where(:project_id => projects.map(&:id)).count,
  :issue_count => Issue.where(:project_id => projects.map(&:id)).count,
  :display_issue_count => display_issue_ids.size,
  :relation_count => IssueRelation.where(:issue_from_id => display_issue_ids).count,
  :normal_path => "/issues/gantt?query_id=#{normal_query.id}&year=#{reference_start.year}&month=#{reference_start.month}&months=6&zoom=2",
  :heavy_path => "/issues/gantt?query_id=#{heavy_query.id}&year=#{heavy_start.year}&month=#{heavy_start.month}&months=12&zoom=4"
}

File.write(ENV.fetch('GANTT_PERF_MANIFEST'), JSON.pretty_generate(manifest))
puts JSON.pretty_generate(manifest)
