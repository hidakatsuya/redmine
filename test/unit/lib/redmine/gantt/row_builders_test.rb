# frozen_string_literal: true

require_relative '../../../../test_helper'

class Redmine::Gantt::RowBuildersTest < ActiveSupport::TestCase
  setup do
    User.current = users(:users_002)
    @project = projects(:projects_001)
    @query = IssueQuery.new(:project => @project, :name => '_')
    @gantt = Redmine::Helpers::Gantt.new(
      :year => User.current.today.year,
      :month => User.current.today.month,
      :months => 2
    )
    @gantt.project = @project
    @gantt.query = @query
  end

  test 'project builder creates a project row with project schedule semantics' do
    row = build(Redmine::Gantt::ProjectRowBuilder, @project, :depth => 0, :parent_row_key => nil)

    assert_instance_of Redmine::Gantt::ProjectRow, row
    assert_equal "project-#{@project.id}", row.row_key
    assert_equal @project.name, row.subject
    assert row.has_children
    assert_equal @project.name, row.schedule.label
    assert_equal @project.start_date, row.schedule.start_on
    assert_equal @project.due_date, row.schedule.end_on
    assert_not row.context_menu?
  end

  test 'version builder creates a version row with completion and closed semantics' do
    version = versions(:versions_001)
    row = build(Redmine::Gantt::VersionRowBuilder, version, :depth => 1,
                                                      :parent_row_key => "project-#{@project.id}")

    assert_instance_of Redmine::Gantt::VersionRow, row
    assert_equal 'version-1', row.row_key
    assert_equal version.visible_fixed_issues.completed_percent, row.completed_percent
    assert row.closed?
    assert_equal version.start_date, row.schedule.start_on
    assert_equal version.due_date, row.schedule.end_on
    assert_not row.editable?
  end

  test 'issue builder creates an issue row with issue schedule and interaction semantics' do
    issue = issues(:issues_003)
    row = build(Redmine::Gantt::IssueRowBuilder, issue, :depth => 1,
                                                    :parent_row_key => "project-#{@project.id}")

    assert_instance_of Redmine::Gantt::IssueRow, row
    assert_equal 'issue-3', row.row_key
    assert_equal issue.subject, row.subject
    assert_equal issue.start_date, row.schedule.start_on
    assert_equal issue.due_before, row.schedule.end_on
    assert_equal issue.status.name, row.schedule.label.split.first
    assert row.context_menu?
    assert_equal issue.editable?(User.current), row.editable?
    assert_equal issue.overdue?, row.overdue?
    assert_equal issue.behind_schedule?, row.behind_schedule?
  end

  private

  def build(builder, record, **attributes)
    builder.new(record, :gantt => @gantt, **attributes).build
  end
end
