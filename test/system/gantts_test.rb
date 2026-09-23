# frozen_string_literal: true

require_relative '../application_system_test_case'

class GanttsTest < ApplicationSystemTestCase
  setup do
    log_user('jsmith', 'jsmith')
  end

  test 'columns display toggle shows status priority assignee updated' do
    visit_gantt
    expand_options

    assert_no_selector 'div.gantt-column[data-gantt-column=status]'
    assert_no_selector 'div.gantt-column[data-gantt-column=priority]'
    assert_no_selector 'div.gantt-column[data-gantt-column=assigned_to]'
    assert_no_selector 'div.gantt-column[data-gantt-column=updated_on]'

    find('#draw_selected_columns').check

    assert_selector 'div.gantt-column[data-gantt-column=subjects]'
    assert_selector 'div.gantt-column[data-gantt-column=status]'
    assert_selector 'div.gantt-column[data-gantt-column=priority]'
    assert_selector 'div.gantt-column[data-gantt-column=assigned_to]'
    assert_selector 'div.gantt-column[data-gantt-column=updated_on]'
  end

  test 'logical rows align across panes' do
    visit_gantt

    rows = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const subjects = [...document.querySelectorAll('[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key]')]
        const timelines = [...document.querySelectorAll('.gantt-timeline-body .gantt-row[data-gantt-row-key]')]
        const timelineByKey = new Map(timelines.map(row => [row.dataset.ganttRowKey, row]))

        return subjects.map(subject => {
          const timeline = timelineByKey.get(subject.dataset.ganttRowKey)
          return {
            subjectTop: subject.getBoundingClientRect().top,
            timelineTop: timeline?.getBoundingClientRect().top
          }
        })
      })()
    JAVASCRIPT

    assert rows.any?
    assert rows.all? {|row| row['timelineTop'].present?}
    rows.each do |row|
      assert_in_delta row['subjectTop'], row['timelineTop'], 0.5
    end

    expand_options
    find('#draw_selected_columns').check

    assert_selector '.gantt-selected-column .gantt-pane-body .gantt-row[data-gantt-row-key]', minimum: 1
  end

  test 'tree toggle updates the same logical rows across every pane' do
    visit_gantt
    expand_options
    find('#draw_selected_columns').check

    project_row = find('[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key="project-1"]')
    subject_issue = '[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key="issue-3"]'
    column_issue = '[data-gantt-column="status"] .gantt-row[data-gantt-row-key="issue-3"]'
    timeline_issue = '.gantt-timeline-body .gantt-row[data-gantt-row-key="issue-3"]'

    project_row.find('.expander').click

    assert_selector subject_issue, visible: :hidden
    assert_selector column_issue, visible: :hidden
    assert_selector timeline_issue, visible: :hidden

    project_row.find('.expander').click

    assert_selector subject_issue, visible: :visible
    assert_selector column_issue, visible: :visible
    assert_selector timeline_issue, visible: :visible
  end

  test 'row highlight spans subjects selected columns and timeline' do
    issues(:issues_005).update_columns(:start_date => nil, :due_date => nil)
    visit_gantt
    expand_options
    find('#draw_selected_columns').check

    %w[project-1 version-2-project-1 issue-5].each do |row_key|
      subject_row = find(
        "[data-gantt-column='subjects'] .gantt-row[data-gantt-row-key='#{row_key}']"
      )
      subject_row.hover
      assert_subject_row_spans_pane subject_row
      assert_row_highlight subject_row, minimum: 3

      timeline_row = find(
        ".gantt-timeline-body .gantt-row[data-gantt-row-key='#{row_key}']"
      )
      hover_visible_timeline_row timeline_row
      assert_row_highlight subject_row, minimum: 3
    end

    find('h2').hover
    assert_no_selector '.gantt-row-hover'
  end

  test 'related issues toggle displays and hides relation arrows' do
    visit_gantt
    expand_options

    assert_selector '.gantt-relations path', minimum: 1
    paths_before_scroll = gantt_draw_paths

    find('#draw_relations').uncheck

    assert_no_selector '.gantt-relations path'

    scroll_gantt_timeline
    find('#draw_relations').check

    assert_selector '.gantt-relations path', minimum: 1
    assert_equal paths_before_scroll, gantt_draw_paths
  end

  test 'progress line toggle draws zigzag line' do
    visit_gantt
    expand_options

    find('#draw_relations').uncheck
    assert_no_selector '.gantt-relations path'

    find('#draw_progress_line').check

    assert_selector '.gantt-relations path', minimum: 1
    paths_before_scroll = gantt_draw_paths

    find('#draw_progress_line').uncheck
    scroll_gantt_timeline
    find('#draw_progress_line').check

    assert_equal paths_before_scroll, gantt_draw_paths
  end

  test 'selected columns can be resized by dragging' do
    visit_gantt
    expand_options

    find('#draw_selected_columns').check

    width_before = column_width('status')
    drag_column_resizer('status', 80)
    width_after = column_width('status')

    assert width_after > width_before
  end

  test 'context menu and tooltip interactions' do
    visit_gantt

    issue1_subject_row = find('.gantt-column[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key="issue-1"]')
    issue1_task_bar = find('.gantt-timeline .gantt-row[data-gantt-row-key="issue-1"] .tooltip')

    # Tooltip for issue task bar
    issue1_task_bar.hover

    within issue1_task_bar do
      issue_link_text = issue1_subject_row.first('a.issue', visible: :all).text
      assert_selector '.tip', text: issue_link_text
    end
    assert_row_highlight issue1_subject_row

    issue1_task_bar.find('.tip').hover
    assert_row_highlight issue1_subject_row

    find('.gantt-pane > header', match: :first).hover
    assert_no_selector '.gantt-row-hover'

    issue1_subject_row.hover
    assert_row_highlight issue1_subject_row

    # Context menu for issue subject
    issue1_subject_row.right_click

    assert_selector '#context-menu'
    assert_selector '#context-menu a.icon-edit'

    # Click outside the context menu to close it
    issue1_subject_row.click(x: -1, y: 0)
    assert_no_selector '#context-menu'

    # Context menu for issue task bar
    issue1_task_bar.right_click

    assert_selector '#context-menu'
    assert_selector '#context-menu a.icon-edit'
  end

  private

  def assert_row_highlight(row, minimum: 2)
    row_key = row['data-gantt-row-key']
    highlighted = all(
      ".gantt-row-hover[data-gantt-row-key='#{row_key}']",
      minimum: minimum
    )
    top = row.evaluate_script('this.getBoundingClientRect().top')

    highlighted.each do |highlight|
      assert_in_delta top, highlight.evaluate_script('this.getBoundingClientRect().top'), 1
      assert_equal 20, highlight.evaluate_script('this.getBoundingClientRect().height')
    end
  end

  def assert_subject_row_spans_pane(row)
    bounds = row.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const row = this.getBoundingClientRect()
        const pane = this.closest('.gantt-pane-body').getBoundingClientRect()
        return {
          rowLeft: row.left,
          rowRight: row.right,
          paneLeft: pane.left,
          paneRight: pane.right
        }
      })()
    JAVASCRIPT

    assert_in_delta bounds['paneLeft'], bounds['rowLeft'], 0.5
    assert_in_delta bounds['paneRight'], bounds['rowRight'], 0.5
  end

  def hover_visible_timeline_row(row)
    point = row.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const timeline = document.querySelector('.gantt-timeline').getBoundingClientRect()
        const row = this.getBoundingClientRect()
        return [timeline.left + 10, row.top + (row.height / 2)]
      })()
    JAVASCRIPT
    page.driver.browser.action.move_to_location(*point).perform
  end

  def visit_gantt
    visit '/projects/ecookbook/issues/gantt'
  end

  def gantt_draw_paths
    all('.gantt-relations path').pluck(:id)
  end

  def scroll_gantt_timeline
    scroll_left = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const timeline = document.querySelector('.gantt-timeline')
        timeline.scrollLeft = Math.min(200, timeline.scrollWidth - timeline.clientWidth)
        return timeline.scrollLeft
      })()
    JAVASCRIPT

    assert_operator scroll_left, :>, 0
  end

  def expand_options
    legend = find('fieldset#options legend')
    legend.click if legend[:class].to_s.include?('collapsed')
  end

  def column_width(id)
    page.evaluate_script("document.querySelector('div.gantt-column[data-gantt-column=\"#{id}\"]').offsetWidth")
  end

  def drag_column_resizer(column_id, distance)
    handle = find("div.gantt-column[data-gantt-column=\"#{column_id}\"] .ui-resizable-e")
    page.driver.browser.action.click_and_hold(handle.native).move_by(distance, 0).release.perform
  end
end
