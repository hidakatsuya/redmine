# frozen_string_literal: true

require_relative '../application_system_test_case'

class GanttsTest < ApplicationSystemTestCase
  setup do
    log_user('jsmith', 'jsmith')
  end

  test 'columns display toggle shows status priority assignee updated' do
    visit_gantt
    expand_options

    assert_no_selector 'div#status'
    assert_no_selector 'div#priority'
    assert_no_selector 'div#assigned_to'
    assert_no_selector 'div#updated_on'

    find('#draw_selected_columns').check

    assert_selector '.gantt_subjects_container.draw_selected_columns'
    assert_selector 'div#status'
    assert_selector 'div#priority'
    assert_selector 'div#assigned_to'
    assert_selector 'div#updated_on'
  end

  test 'logical rows align across panes' do
    visit_gantt

    rows = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const subjects = [...document.querySelectorAll('.gantt_subjects .gantt-row.gantt-subject-row')]
        const timelines = [...document.querySelectorAll('.gantt-timeline-body .gantt-row.gantt-timeline-row')]
        const timelineByIndex = new Map(timelines.map(row => [row.dataset.numberOfRows, row]))

        return subjects.map(subject => {
          const timeline = timelineByIndex.get(subject.dataset.numberOfRows)
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

    assert_selector '.gantt_selected_column_content .gantt-row.gantt-column-row', minimum: 1
  end

  test 'related issues toggle displays and hides relation arrows' do
    visit_gantt
    expand_options

    assert_selector '#gantt_draw_area path', minimum: 1
    paths_before_scroll = gantt_draw_paths

    find('#draw_relations').uncheck

    assert_no_selector '#gantt_draw_area path'

    scroll_gantt_timeline
    find('#draw_relations').check

    assert_selector '#gantt_draw_area path', minimum: 1
    assert_equal paths_before_scroll, gantt_draw_paths
  end

  test 'progress line toggle draws zigzag line' do
    visit_gantt
    expand_options

    find('#draw_relations').uncheck
    assert_no_selector '#gantt_draw_area path'

    find('#draw_progress_line').check

    assert_selector '#gantt_draw_area path', minimum: 1
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

    issue1_subject_row = find('#issue-1')
    issue1_task_bar = find('div.tooltip[data-collapse-expand="issue-1"]')

    # Tooltip for issue task bar
    issue1_task_bar.hover

    within issue1_task_bar do
      assert_selector 'span.tip', text: issue1_subject_row.first('a.issue').text
    end

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

  def visit_gantt
    visit '/projects/ecookbook/issues/gantt'
  end

  def gantt_draw_paths
    all('#gantt_draw_area path').pluck(:id)
  end

  def scroll_gantt_timeline
    scroll_left = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const timeline = document.querySelector('#gantt_area')
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
    page.evaluate_script("document.querySelector('div##{id}').offsetWidth")
  end

  def drag_column_resizer(column_id, distance)
    handle = find("div##{column_id} .ui-resizable-e")
    page.driver.browser.action.click_and_hold(handle.native).move_by(distance, 0).release.perform
  end
end
