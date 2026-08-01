# frozen_string_literal: true

require_relative '../../../../test_helper'

class Redmine::Gantt::ChartTest < ActiveSupport::TestCase
  setup do
    User.current = users(:users_002)
    @project = projects(:projects_001)
    @query = IssueQuery.new(:project => @project, :name => '_')
  end

  test 'builds immutable rows in project version and issue traversal order' do
    chart = build_chart
    rows = chart.rows
    project_index = rows.index {|row| row.row_key == "project-#{@project.id}"}
    version_index = rows.index {|row| row.row_key == 'version-2'}
    issue_index = rows.index {|row| row.row_key == 'issue-2'}

    assert rows.any?
    assert_equal rows.map(&:row_key).uniq, rows.map(&:row_key)
    assert rows.all? {|row| row.record.is_a?(::Project) || row.record.is_a?(::Version) || row.record.is_a?(::Issue)}
    assert_instance_of Redmine::Gantt::Project, rows[project_index]
    assert_instance_of Redmine::Gantt::Version, rows[version_index]
    assert_instance_of Redmine::Gantt::Issue, rows[issue_index]
    assert_operator project_index, :<, version_index
    assert_operator version_index, :<, issue_index
    assert_equal 'version-2', rows[issue_index].parent_row_key
    assert rows.frozen?
  end

  test 'describes project and issue hierarchy with stable parent row keys' do
    chart = build_chart
    project_row = chart.rows.find {|row| row.row_key == "project-#{@project.id}"}
    child_row = chart.rows.find {|row| row.parent_row_key == project_row.row_key}
    subproject = chart.rows.find {|row| row.project? && row.record.parent_id == @project.id}

    assert_nil project_row.parent_row_key
    assert child_row
    assert_operator child_row.depth, :>, project_row.depth
    assert subproject
    assert_equal "project-#{@project.id}", subproject.parent_row_key
  end

  test 'exposes truncation without changing the legacy gantt truncation state' do
    gantt = build_gantt(:max_rows => 2)
    chart = Redmine::Gantt::Chart.build(gantt, :query => @query)

    assert_equal 2, chart.rows.size
    assert_predicate chart, :truncated?
    assert_not gantt.truncated
  end

  test 'builds the chart without retaining a builder or construction dependencies' do
    chart = build_chart

    assert_not Redmine::Gantt::Chart.const_defined?(:Builder, false)
    assert_nil chart.instance_variable_get(:@gantt)
    assert_nil chart.instance_variable_get(:@query)
  end

  test 'captures selected columns, scale segments, relations, and today in the chart snapshot' do
    chart = build_chart
    visible_keys = chart.rows.select(&:issue?).map(&:row_key)

    assert_equal @query.inline_columns.reject {|column| Redmine::Helpers::Gantt::UNAVAILABLE_COLUMNS.include?(column.name)},
                 chart.selected_columns
    assert_equal 1 + [chart.zoom > 1, chart.zoom > 3, chart.zoom > 2].count(true), chart.header_layers
    assert chart.scale_segments.any?
    assert chart.scale_segments.frozen?
    assert chart.scale_segments.all? {|segment| segment.kind && !segment.respond_to?(:css_classes)}
    assert chart.relations.frozen?
    chart.relations.each do |relation|
      assert_includes visible_keys, relation.from_row_key
      assert_includes visible_keys, relation.to_row_key
    end
    if User.current.today.between?(chart.date_from, chart.date_to)
      assert_equal (User.current.today - chart.date_from + 1).to_i, chart.today_offset
    else
      assert_nil chart.today_offset
    end
  end

  private

  def build_chart
    Redmine::Gantt::Chart.build(build_gantt, :query => @query)
  end

  def build_gantt(options={})
    Redmine::Helpers::Gantt.new(options).tap do |gantt|
      gantt.project = @project
      gantt.query = @query
    end
  end
end
