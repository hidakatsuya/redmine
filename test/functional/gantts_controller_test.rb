# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../test_helper'

class GanttsControllerTest < Redmine::ControllerTest
  def test_gantt_should_work
    i2 = Issue.find(2)
    i2.update_attribute(:due_date, 1.month.from_now)
    with_settings :gravatar_enabled => '1' do
      get(
        :show,
        :params => {
          :project_id => 1
        }
      )
    end
    assert_response :success

    # query form
    assert_select 'form#query_form' do
      assert_select 'div#query_form_with_buttons.hide-when-print' do
        assert_select 'div#query_form_content' do
          assert_select 'fieldset#filters.collapsible'
          assert_select 'fieldset#options'
        end
        assert_select 'p.contextual' do
          prev_month, next_month = User.current.today.prev_month, User.current.today.next_month
          assert_select(
            'a[accesskey="p"][href=?]',
            project_gantt_path(:project_id => 1, :month => prev_month.month, :year => prev_month.year)
          )
          assert_select(
            'a[accesskey="n"][href=?]',
            project_gantt_path(:project_id => 1, :month => next_month.month, :year => next_month.year)
          )
        end
        assert_select 'p.buttons'
      end
    end

    # Assert context menu on issues subject and gantt bar
    assert_select 'div.issue-subject.hascontextmenu'
    assert_select 'div.tooltip.hascontextmenu' do
      assert_select 'img[class="gravatar avatar"]'
    end
    assert_select "form[data-cm-url=?]", '/issues/context_menu'

    # Issue with start and due dates
    i = Issue.find(1)
    assert_not_nil i.due_date
    assert_select "div a.issue", /##{i.id}/
    # Issue with on a targeted version should not be in the events but loaded in the html
    i = Issue.find(2)
    assert_select "div a.issue", /##{i.id}/
  end

  def test_gantt_at_minimal_zoom
    get(
      :show,
      :params => {
        :project_id => 1,
        :zoom => 1
      }
    )
    assert_response :success
    assert_select 'input[type=hidden][name=zoom][value=?]', '1'
  end

  def test_gantt_at_maximal_zoom
    get(
      :show,
      :params => {
        :project_id => 1,
        :zoom => 4
      }
    )
    assert_response :success
    assert_select 'input[type=hidden][name=zoom][value=?]', '4'
  end

  def test_gantt_should_work_without_issue_due_dates
    Issue.update_all("due_date = NULL")
    get(:show, :params => {:project_id => 1})
    assert_response :success
  end

  def test_gantt_should_work_without_issue_and_version_due_dates
    Issue.update_all("due_date = NULL")
    Version.update_all("effective_date = NULL")
    get(:show, :params => {:project_id => 1})
    assert_response :success
  end

  def test_show_should_run_custom_query
    query = IssueQuery.create!(:name => 'Gantt Query', :description => 'Description for Gantt Query', :visibility => IssueQuery::VISIBILITY_PUBLIC)
    get(
      :show,
      :params => {
        :query_id => query.id
      }
    )
    assert_response :success
    assert_select 'h2', :text => query.name
    assert_select '#sidebar a.query.selected[title=?]', query.description, :text => query.name
  end

  def test_gantt_should_work_cross_project
    get :show
    assert_response :success
  end

  def test_gantt_should_not_disclose_private_projects
    get :show
    assert_response :success

    assert_select 'a', :text => /eCookbook/
    # Root private project
    assert_select 'a', :text => /OnlineStore/, :count => 0
    # Private children of a public project
    assert_select 'a', :text => /Private child of eCookbook/, :count => 0
  end

  def test_gantt_should_display_relations
    IssueRelation.delete_all
    issue1 = Issue.generate!(:start_date => 1.day.from_now.to_date, :due_date => 3.day.from_now.to_date)
    issue2 = Issue.generate!(:start_date => 1.day.from_now.to_date, :due_date => 3.day.from_now.to_date)
    IssueRelation.create!(:issue_from => issue1, :issue_to => issue2, :relation_type => 'precedes')

    get :show
    assert_response :success

    assert_select 'div.gantt[data-gantt--chart-relations-value*=?]',
                  "\"from_row_key\":\"issue-#{issue1.id}\""
    assert_select 'div.gantt[data-gantt--chart-relations-value*=?]',
                  "\"to_row_key\":\"issue-#{issue2.id}\""
  end

  test 'renders only selected columns in chart rows' do
    get(
      :show,
      :params => {
        :project_id => 1,
        :set_filter => 1,
        :c => %w[status priority],
        :query => {:draw_selected_columns => '1'}
      }
    )

    assert_response :success
    assert_select '.gantt__column-header', :count => 2
    assert_select '.gantt__row--issue .gantt__column-cell', :minimum => 2
    assert_select '.gantt[style*="--gantt-selected-columns-count: 2"]'
  end

  def test_gantt_should_export_to_pdf
    get(
      :show,
      :params => {
        :project_id => 1,
        :months => 1,
        :format => 'pdf'
      }
    )
    assert_response :success
    assert_equal 'application/pdf', @response.media_type
    assert @response.body.starts_with?('%PDF')
  end

  def test_gantt_should_export_to_pdf_cross_project
    get(:show, :params => {:format => 'pdf'})
    assert_response :success
    assert_equal 'application/pdf', @response.media_type
    assert @response.body.starts_with?('%PDF')
  end

  if Object.const_defined?(:MiniMagick) && convert_installed?
    def test_gantt_should_export_to_png
      get(
        :show,
        :params => {
          :project_id => 1,
          :zoom => 4,
          :format => 'png'
        }
      )
      assert_response :success
      assert_equal 'image/png', @response.media_type
    end
  end

  def test_gantt_should_respect_gantt_months_limit_setting
    with_settings :gantt_months_limit => '40' do
      # `months` parameter can be less than or equal to
      # `Setting.gantt_months_limit`
      get(
        :show,
        :params => {
          :project_id => 1,
          :zoom => 4,
          :months => 40
        }
      )
      assert_response :success
      assert_select 'div.gantt__scale-segment--month>a', :text => /^[\d-]+$/, :count => 40

      # Displays 6 months (the default value for `months`) if `months` exceeds
      # gant_months_limit
      get(
        :show,
        :params => {
          :project_id => 1,
          :zoom => 4,
          :months => 41
        }
      )
      assert_response :success
      assert_select 'div.gantt__scale-segment--month>a', :text => /^[\d-]+$/, :count => 6
    end
  end

  test 'renders project tree with child issues and bars' do
    prepare_stable_gantt_data

    @request.session[:user_id] = 2

    project = projects(:projects_001)

    get(:show, params: { project_id: project.id })
    assert_response :success

    # eCookbook
    assert_subject_row('project-1', row: '0', text: project.name)
    assert_chart_row('project-1', row: '0', selector: 'div.task.project.task_todo')

    assert_issue_row(3, 'Bug #3', row: '1')
    assert_chart_row('issue-3', row: '1', selector: 'div.task.leaf.task_todo')

    assert_issue_row(7, 'Bug #7', row: '2')
    assert_chart_row('issue-7', row: '2', selector: 'div.task.leaf.task_todo')

    assert_issue_row(1, 'Bug #1', row: '3')
    assert_chart_row('issue-1', row: '3', selector: 'div.task.leaf.task_todo')

    # Version 1.0
    assert_subject_row('version-2', row: '4', text: '1.0')
    assert_chart_row('version-2', row: '4', selector: 'div.task.version.task_todo')

    assert_issue_row(2, 'Feature request #2', row: '5')
    assert_chart_row('issue-2', row: '5', selector: 'div.task.leaf.task_todo')

    # Private child of eCookbook
    assert_subject_row(
      'project-5',
      row: '6',
      text: projects(:projects_005).name
    )
    assert_chart_row('project-5', row: '6', selector: 'div.task.project.task_todo')

    assert_issue_row(6, 'Bug #6', row: '7')
    assert_chart_row('issue-6', row: '7', selector: 'div.task.leaf.task_todo')

    assert_issue_row(9, 'Bug #9', row: '8')
    assert_chart_row('issue-9', row: '8', selector: 'div.task.leaf.task_todo')

    assert_issue_row(10, 'Bug #10', row: '9')
    assert_chart_row('issue-10', row: '9', selector: 'div.task.leaf.task_todo')
    assert_select 'div.gantt[data-gantt--chart-relations-value*=?]', "\"from_row_key\":\"issue-10\""

    # eCookbook Subproject1
    assert_subject_row(
      'project-3',
      row: '10',
      text: projects(:projects_003).name
    )
    assert_issue_row(5, 'Bug #5', row: '11')
    assert_issue_row(13, 'Bug #13', row: '12')
    assert_issue_row(14, 'Bug #14', row: '13')
  end

  test 'renders chart with selected start month and year' do
    prepare_stable_gantt_data

    @request.session[:user_id] = 2

    project = projects(:projects_005)

    selected_start = User.current.today.prev_month.beginning_of_month
    get(
      :show,
      params: {
        project_id: project.id,
        month: selected_start.month,
        year: selected_start.year
      }
    )
    assert_response :success

    assert_select 'select#month option[selected=selected][value=?]', selected_start.month.to_s
    assert_select 'select#year option[selected=selected][value=?]', selected_start.year.to_s

    6.times do |offset|
      m = selected_start.since(offset.month)
      assert_select 'div.gantt__scale-segment--month > a', text: "#{m.year}-#{m.month}"
    end

    # eCookbook
    assert_subject_row('project-1', row: '0', text: projects(:projects_001).name)
    assert_chart_row('project-1', row: '0', selector: 'div.task.project.task_todo')

    # Private child of eCookbook
    assert_subject_row(
      'project-5',
      row: '1',
      text: project.name
    )
    assert_chart_row('project-5', row: '1', selector: 'div.task.project.task_todo')

    # Bug #6
    assert_issue_row(6, 'Bug #6', row: '2')
    assert_chart_row('issue-6', row: '2', selector: 'div.task.leaf.task_todo')

    # Bug #9
    assert_issue_row(9, 'Bug #9', row: '3')
    assert_chart_row('issue-9', row: '3', selector: 'div.task.leaf.task_todo')

    # Bug #10
    assert_issue_row(10, 'Bug #10', row: '4')
    assert_chart_row('issue-10', row: '4', selector: 'div.task.leaf.task_todo')
    assert_select 'div.gantt[data-gantt--chart-relations-value*=?]', "\"from_row_key\":\"issue-10\""
  end

  test 'shows six months starting from current month' do
    prepare_stable_gantt_data

    @request.session[:user_id] = 2

    project = projects(:projects_001)

    get :show, params: { project_id: project.id }
    assert_response :success

    start_of_month = User.current.today.beginning_of_month
    6.times do |offset|
      m = start_of_month.since(offset.months)

      assert_select 'div.gantt__scale-segment--month > a', text: "#{m.year}-#{m.month}"
    end

    assert_select 'input#months[value=?]', '6'
    assert_select 'select#month option[selected=selected][value=?]', User.current.today.month.to_s
    assert_select 'select#year option[selected=selected][value=?]', User.current.today.year.to_s
    assert_select 'input#zoom[value=?]', '2'
  end

  private

  def assert_subject_row(row_key, row:, text:)
    nth = row.to_i + 1
    assert_select "div.gantt__body > div.gantt__row:nth-child(#{nth})[data-row-key=?]", row_key do
      assert_select 'a', text: text
    end
  end

  def assert_issue_row(issue_id, link_text, row:)
    nth = row.to_i + 1
    selector = "div.gantt__body > div.gantt__row:nth-child(#{nth})[data-row-key=\"issue-#{issue_id}\"]"
    assert_select selector do
      assert_select 'a.issue', text: link_text
    end
  end

  def assert_chart_row(row_key, row:, selector:)
    matcher = "#gantt_area > div.gantt__row[data-row-key=\"#{row_key}\"] #{selector}"
    assert_select matcher, minimum: 1
  end

  # Freezes today and resets the start and due dates of issues and versions in the eCookbook project and its descendants to fixed values
  # so the Gantt layout uses deterministic dates, bar positions stay stable across runs, and the tests remain easy to execute.
  def prepare_stable_gantt_data
    issues(:issues_003).update!(start_date: Date.new(2025, 9, 30), due_date: Date.new(2025, 10, 10))
    issues(:issues_007).update!(start_date: Date.new(2025, 10, 5), due_date: Date.new(2025, 10, 15))
    issues(:issues_001).update!(start_date: Date.new(2025, 10, 14), due_date: Date.new(2025, 10, 25))
    issues(:issues_002).update!(start_date: Date.new(2025, 10, 13), due_date: nil)
    issues(:issues_006).update!(start_date: Date.new(2025, 10, 15), due_date: Date.new(2025, 10, 16))
    issues(:issues_009).update!(start_date: Date.new(2025, 10, 15), due_date: Date.new(2025, 10, 16))
    issues(:issues_010).update!(start_date: Date.new(2025, 10, 15), due_date: Date.new(2025, 10, 16))

    Version.find(2).update!(effective_date: Date.new(2025, 11, 4))

    travel_to Date.new(2025, 10, 15)
  end
end
