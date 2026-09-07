# frozen_string_literal: true

require_relative '../../../../test_helper'

class Redmine::Gantt::DatasetTest < ActiveSupport::TestCase
  setup do
    User.current = users(:users_001)
    @project = Project.generate!
    @other = Project.generate!
    @version = Version.generate!(:project => @project, :sharing => 'system')
    @issue = Issue.generate!(:project => @project, :fixed_version => @version)
    @other_issue = Issue.generate!(:project => @other, :fixed_version => @version)
    @gantt = Redmine::Gantt.new(:max_rows => nil)
    @gantt.query = IssueQuery.new(:name => '_', :filters => {'project_id' => {:operator => '=', :values => [@project.id.to_s, @other.id.to_s]}})
  end

  test 'shared versions have distinct display keys and their own project children' do
    rows = @gantt.chart.rows
    assert_equal rows.map(&:row_key).uniq, rows.map(&:row_key)
    [@project, @other].each do |project|
      section = @gantt.project_section(project)
      version = section.rows.find(&:version?)
      issue = section.rows.find(&:issue?)
      assert_equal "project-#{project.id}-version-#{@version.id}", version.row_key
      assert version.expandable?
      assert_equal version.row_key, issue.parent_row_key
    end
  end

  test 'project section matches the complete chart without building other view models' do
    expected = @gantt.chart.sections.find {|section| section.project == @other}.rows
    @gantt.dataset.projects.find {|project| project.id == @project.id}.expects(:overdue?).never
    actual = @gantt.project_section(@other).rows

    assert_equal expected.map(&:row_key), actual.map(&:row_key)
    assert_equal expected.map(&:depth), actual.map(&:depth)
    assert_equal expected.map(&:parent_row_key), actual.map(&:parent_row_key)
  end

  test 'section lookup preserves the global row limit' do
    limited = Redmine::Gantt.new(:max_rows => 4)
    limited.query = @gantt.query
    first, second = limited.dataset.each_project.to_a
    assert_equal 3, first.last
    assert_equal 1, second.last
    assert_equal limited.chart.sections.last.rows.map(&:row_key), limited.project_section(second.first).rows.map(&:row_key)
    assert limited.chart.truncated?
  end

  test 'chart setup does not eagerly build every row view model' do
    Redmine::Gantt::Issue.expects(:build).never
    Redmine::Gantt::Version.expects(:build).never

    assert_equal 2, @gantt.chart.sections.size
  end

  test 'existing sections keep their dataset after query reassignment' do
    section = @gantt.project_section(@project)
    @gantt.query = IssueQuery.new(:project => @other, :name => '_')

    assert_equal [@issue.id], section.rows.select(&:issue?).map {|row| row.issue.id}
  end

  test 'query reassignment discards data and chart caches' do
    @gantt.chart
    @gantt.query = IssueQuery.new(:project => @other, :name => '_')

    assert_nil @gantt.project_section(@project)
    assert_equal [@other_issue.id], @gantt.issues.map(&:id)
  end

  test 'exports and HTML use the same bounded logical rows' do
    gantt = Redmine::Gantt.new(:max_rows => 4)
    gantt.query = @gantt.query
    logical_rows = gantt.dataset.each_row.to_a
    html_rows = gantt.chart.rows

    assert_equal logical_rows.map {|_record, _depth, key| key}, html_rows.map(&:row_key)
    assert_equal logical_rows.map {|_record, depth| depth}, html_rows.map(&:depth)
  end

  test 'section lookup never bypasses issue visibility' do
    @other.update!(:is_public => false)
    User.current = User.anonymous
    query = @gantt.query
    @gantt.query = query

    assert_nil @gantt.project_section(@other)
    assert_not_includes @gantt.chart.rows.select(&:issue?).map {|row| row.issue.id}, @other_issue.id
  end
end
