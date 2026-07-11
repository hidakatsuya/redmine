# frozen_string_literal: true

require_relative '../../../../test_helper'

class Redmine::Gantt::ChartBuilderTest < ActiveSupport::TestCase
  setup do
    User.current = users(:users_002)
    @project = projects(:projects_001)
    @query = IssueQuery.new(:project => @project, :name => '_')
  end

  test 'builds one view model row for each visible record' do
    chart = build_chart

    assert chart.rows.any?
    assert_equal chart.rows.map(&:row_key).uniq, chart.rows.map(&:row_key)
    assert chart.rows.all? {|row| row.record.is_a?(Project) || row.record.is_a?(Version) || row.record.is_a?(Issue)}
    assert chart.rows.grep(Redmine::Gantt::ProjectRow).any?
    assert chart.rows.grep(Redmine::Gantt::VersionRow).any?
    assert chart.rows.grep(Redmine::Gantt::IssueRow).any?
  end

  test 'describes hierarchy with stable parent row keys' do
    chart = build_chart
    project_row = chart.rows.find {|row| row.row_key == "project-#{@project.id}"}
    child_row = chart.rows.find {|row| row.parent_row_key == project_row.row_key}

    assert_nil project_row.parent_row_key
    assert child_row
    assert_operator child_row.depth, :>, project_row.depth
  end

  test 'keeps typed rows in project version and issue traversal order' do
    rows = build_chart.rows
    project_index = rows.index {|row| row.row_key == "project-#{@project.id}"}
    version_index = rows.index {|row| row.row_key == 'version-2'}
    issue_index = rows.index {|row| row.row_key == 'issue-2'}

    assert_instance_of Redmine::Gantt::ProjectRow, rows[project_index]
    assert_instance_of Redmine::Gantt::VersionRow, rows[version_index]
    assert_instance_of Redmine::Gantt::IssueRow, rows[issue_index]
    assert_operator project_index, :<, version_index
    assert_operator version_index, :<, issue_index
    assert_equal 'version-2', rows[issue_index].parent_row_key
  end

  test 'places a subproject below its visible parent project' do
    chart = build_chart
    subproject = chart.rows.find do |row|
      row.project? && row.record.parent_id == @project.id
    end

    assert subproject
    assert_equal "project-#{@project.id}", subproject.parent_row_key
  end

  test 'limits rows without asking the view to stop rendering' do
    gantt = build_gantt(:max_rows => 2)
    chart = Redmine::Gantt::ChartBuilder.new(gantt, :query => @query).build

    assert_equal 2, chart.rows.size
    assert gantt.truncated
  end

  test 'only includes relations whose endpoints are visible' do
    chart = build_chart
    visible_keys = chart.rows.select(&:issue?).map(&:row_key)

    chart.relations.each do |relation|
      assert_includes visible_keys, relation.from_row_key
      assert_includes visible_keys, relation.to_row_key
    end
  end

  private

  def build_chart
    Redmine::Gantt::ChartBuilder.new(build_gantt, :query => @query).build
  end

  def build_gantt(options={})
    Redmine::Helpers::Gantt.new(options).tap do |gantt|
      gantt.project = @project
      gantt.query = @query
    end
  end
end
