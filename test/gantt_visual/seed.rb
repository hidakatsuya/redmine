# frozen_string_literal: true
# rubocop:disable all

# Run only against the dedicated visual-test database, after schema loading.
require 'active_record/fixtures'
require 'json'
require_relative '../object_helpers'
include ObjectHelpers

raise 'Dedicated database required' unless ActiveRecord::Base.connection_db_config.database.include?('/gantt_visual/')
ActiveRecord::FixtureSet.create_fixtures(Rails.root.join('test/fixtures'), Dir[Rails.root.join('test/fixtures/*.yml')].map {|p| File.basename(p, '.yml')})
User.current = User.find(1)
Setting.default_language = 'en'
Setting.login_required = '0'
Setting.gravatar_enabled = '0'
Setting.non_working_week_days = %w(6 7)
Setting.gantt_items_limit = '500'
Setting.gantt_months_limit = '24'
Setting.issue_done_ratio = 'issue_field'
Setting.cross_project_issue_relations = '1'
User.find(1).update!(:password => 'visual-password', :password_confirmation => 'visual-password', :must_change_passwd => false)
User.find(2).update!(:password => 'visual-password', :password_confirmation => 'visual-password', :must_change_passwd => false)
%w(ja ar).each do |language|
  User.generate!(:login => "visual-#{language}", :admin => true, :language => language,
                 :password => 'visual-password', :password_confirmation => 'visual-password')
end
User.where.not(:type => 'Group').each do |user|
  user.pref.update!(:time_zone => 'UTC')
end

projects = {}
%w(basic hierarchy shared dates progress bulk).each do |name|
  projects[name] = Project.generate!(:name => "Visual #{name}", :identifier => "visual-#{name}", :is_public => true,
                                   :enabled_module_names => %w(issue_tracking gantt), :tracker_ids => [1, 2, 3])
end
projects['child'] = Project.generate!(:name => 'Visual child', :identifier => 'visual-child', :parent => projects['hierarchy'],
                                     :enabled_module_names => %w(issue_tracking gantt), :tracker_ids => [1])
projects['grandchild'] = Project.generate!(:name => 'Visual grandchild', :identifier => 'visual-grandchild', :parent => projects['child'],
                                          :enabled_module_names => %w(issue_tracking gantt), :tracker_ids => [1])
projects['private'] = Project.generate!(:name => 'Visual private', :identifier => 'visual-private', :parent => projects['hierarchy'], :is_public => false,
                                       :enabled_module_names => %w(issue_tracking gantt), :tracker_ids => [1])
User.add_to_project(User.find(2), projects['hierarchy'], Role.find(2))
User.add_to_project(User.find(2), projects['basic'], Role.find(2))
records = {}
add = lambda do |key, project, attributes = {}|
  records[key] = Issue.generate!({:project => projects.fetch(project), :subject => "#{key}: visual regression",
                                  :start_date => Date.new(2026, 8, 1), :due_date => Date.new(2026, 9, 20),
                                  :author_id => 1, :done_ratio => 0}.merge(attributes))
end
version = Version.generate!(:project => projects['basic'], :name => 'Release 1', :effective_date => Date.new(2026, 9, 20))
add.call('basic-open', 'basic', :assigned_to_id => 2)
add.call('basic-version', 'basic', :fixed_version => version, :done_ratio => 33)
add.call('basic-closed', 'basic', :status_id => 5, :done_ratio => 100)
add.call('basic-long', 'basic', :subject => 'Long subject 日本語 العربية ' * 8)
add.call('basic-private', 'basic', :is_private => true)
add.call('parent', 'hierarchy')
add.call('child-task', 'hierarchy', :parent_issue_id => records['parent'].id)
add.call('grandchild-task', 'hierarchy', :parent_issue_id => records['child-task'].id, :done_ratio => 50)
add.call('sibling-task', 'hierarchy', :parent_issue_id => records['parent'].id)
add.call('child-project-task', 'child')
add.call('grandchild-project-task', 'grandchild')
add.call('private-project-task', 'private')
shared = Version.generate!(:project => projects['hierarchy'], :name => 'Shared release', :sharing => 'system', :effective_date => Date.new(2026, 10, 1))
add.call('shared-owner', 'hierarchy', :fixed_version => shared)
add.call('shared-guest', 'shared', :fixed_version => shared)
closed = Version.generate!(:project => projects['shared'], :name => 'Closed release', :effective_date => Date.new(2026, 8, 31))
add.call('closed-version', 'shared', :fixed_version => closed, :status_id => 5, :done_ratio => 100)
closed.update!(:status => 'closed')
add.call('no-start', 'dates', :start_date => nil)
add.call('no-due', 'dates', :due_date => nil)
add.call('no-dates', 'dates', :start_date => nil, :due_date => nil)
add.call('version-due', 'dates', :due_date => nil, :fixed_version => shared)
add.call('before', 'dates', :start_date => Date.new(2026, 4, 1), :due_date => Date.new(2026, 5, 1))
add.call('after', 'dates', :start_date => Date.new(2027, 1, 1), :due_date => Date.new(2027, 2, 1))
add.call('spanning', 'dates', :start_date => Date.new(2026, 5, 1), :due_date => Date.new(2027, 2, 1), :done_ratio => 50)
add.call('one-day', 'dates', :start_date => Date.new(2026, 6, 1), :due_date => Date.new(2026, 6, 1))
add.call('leap', 'dates', :start_date => Date.new(2024, 2, 28), :due_date => Date.new(2024, 3, 1))
[0, 1, 33, 50, 99, 100].each do |percent|
  add.call("progress-#{percent}", 'progress', :done_ratio => percent, :start_date => Date.new(2026, 8, 1), :due_date => Date.new(2026, 8, 23))
end
100.times do |index|
  add.call(format('bulk-%03d', index), 'bulk', :start_date => Date.new(2026, 6, 1) + index,
           :due_date => Date.new(2026, 6, 15) + index, :done_ratio => index)
end
[26, 30].each do |parent_index|
  [1, 2].each do |offset|
    records[format('bulk-%03d', parent_index + offset)].update!(:parent_issue_id => records[format('bulk-%03d', parent_index)].id)
  end
end
[['basic-open', 'basic-long', 'blocks'], ['shared-owner', 'shared-guest', 'blocks'],
 ['bulk-048', 'bulk-053', 'blocks'], ['bulk-029', 'bulk-033', 'blocks']].each do |from, to, type|
  IssueRelation.create!(:issue_from => records[from], :issue_to => records[to], :relation_type => type)
end
# Precedes is inserted without schedule propagation so the fixture dates stay explicit.
IssueRelation.insert_all!([{:issue_from_id => records['basic-version'].id, :issue_to_id => records['basic-closed'].id, :relation_type => 'precedes', :delay => 0}])
cf = IssueCustomField.create!(:name => 'Visual field', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2, 3])
records['basic-long'].custom_field_values = {cf.id => 'Long custom value ' * 8}
records['basic-long'].save!

queries = {}
projects.each do |name, project|
  ids = name == 'hierarchy' ? %w(hierarchy child grandchild private).map {|n| projects[n].id} : [project.id]
  query = IssueQuery.new(:name => "Visual #{name}", :user_id => 1, :visibility => Query::VISIBILITY_PUBLIC,
                         :filters => {'project_id' => {:operator => '=', :values => ids.map(&:to_s)}})
  query.column_names = [:subject, :status, :priority, :assigned_to, :updated_on, :"cf_#{cf.id}"]
  query.save!
  queries[name] = query.id
end
both = IssueQuery.new(:name => 'Visual shared both', :user_id => 1, :visibility => Query::VISIBILITY_PUBLIC,
                     :filters => {'project_id' => {:operator => '=', :values => %w(hierarchy shared).map {|n| projects[n].id.to_s}}})
both.save!
queries['shared-both'] = both.id
manifest = {:projects => projects.transform_values(&:id), :issues => records.transform_values(&:id), :queries => queries,
            :issue_projects => records.transform_values(&:project_id),
            :versions => {:basic => version.id, :shared => shared.id}, :custom_field => cf.id}
File.write(ENV.fetch('GANTT_VISUAL_MANIFEST'), JSON.pretty_generate(manifest))
puts "Prepared #{records.size} issues for visual cases"
