# frozen_string_literal: true

require_relative '../application_system_test_case'

class GanttsTest < ApplicationSystemTestCase
  setup do
    log_user('jsmith', 'jsmith')
  end

  test 'columns display toggle shows status priority assignee updated' do
    visit_gantt
    expand_options

    assert_no_selector 'td#status'
    assert_no_selector 'td#priority'
    assert_no_selector 'td#assigned_to'
    assert_no_selector 'td#updated_on'

    find('#draw_selected_columns').check

    assert_selector 'div.gantt_subjects_container.draw_selected_columns'
    assert_selector 'td#status'
    assert_selector 'td#priority'
    assert_selector 'td#assigned_to'
    assert_selector 'td#updated_on'
  end

  test 'related issues toggle displays and hides relation arrows' do
    visit_gantt
    expand_options

    assert_selector '#gantt_draw_area path', minimum: 1

    find('#draw_relations').uncheck

    assert_no_selector '#gantt_draw_area path'

    find('#draw_relations').check

    assert_selector '#gantt_draw_area path', minimum: 1
  end

  test 'progress line toggle draws zigzag line' do
    visit_gantt
    expand_options

    find('#draw_relations').uncheck
    assert_no_selector '#gantt_draw_area path'

    find('#draw_progress_line').check

    assert_selector '#gantt_draw_area path', minimum: 1
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

  test 'row highlight spans subjects columns and empty chart space' do
    issues(:issues_005).update_columns(start_date: nil, due_date: nil)
    visit_gantt
    expand_options
    find('#draw_selected_columns').check

    ['.project-name', '.version-name', '#issue-5'].each do |selector|
      row = first(".gantt_subjects #{selector}")
      row.hover
      assert_row_highlight(row)

      # Hit the empty part of the chart, including the row without a task bar.
      hover_chart_row(row)
      assert_row_highlight(row)
    end

    find('h2').hover
    assert_no_selector '.gantt_row_highlight:not([hidden])'
  end

  test 'row highlight follows shared versions after collapsing and scrolling' do
    versions(:versions_002).update_columns(sharing: 'system')
    issues(:issues_005).update_columns(fixed_version_id: 2, start_date: Date.today, due_date: Date.today + 5)
    visit '/projects/ecookbook/issues/gantt?zoom=4&months=6'
    expand_options
    find('#draw_selected_columns').check

    versions = all('.gantt_subjects #version-2', count: 2)
    versions.each do |row|
      row.hover
      assert_row_highlight(row)
    end

    versions.first.find('.expander').click
    versions.last.hover
    assert_row_highlight(versions.last)

    page.execute_script('document.querySelector("#gantt_area").scrollLeft = 500')
    hover_chart_row(versions.last)
    assert_row_highlight(versions.last)

    find('#draw_selected_columns').uncheck
    versions.last.hover
    assert_row_highlight(versions.last)
    find('#draw_selected_columns').check
    first('.gantt_selected_column_content > div').hover
    assert_selector '.gantt_row_highlight:not([hidden])', minimum: 3

    versions.first.find('.expander').click
    versions.last.hover
    assert_row_highlight(versions.last)
  end

  private

  def hover_chart_row(row)
    row.hover
    offset = row.evaluate_script(<<~JS)
      document.querySelector('#gantt_area').getBoundingClientRect().left + 10 -
        (this.getBoundingClientRect().left + this.getBoundingClientRect().width / 2)
    JS
    page.driver.browser.action.move_to(row.native).move_by(offset, 0).perform
  end

  def assert_row_highlight(row)
    assert_selector '.gantt_row_highlight:not([hidden])', minimum: 2
    top = row.evaluate_script('this.getBoundingClientRect().top')
    all('.gantt_row_highlight:not([hidden])').each do |highlight|
      assert_in_delta top, highlight.evaluate_script('this.getBoundingClientRect().top'), 1
      assert_equal 20, highlight.evaluate_script('this.getBoundingClientRect().height')
    end
  end

  def visit_gantt
    visit '/projects/ecookbook/issues/gantt'
  end

  def expand_options
    legend = find('fieldset#options legend')
    legend.click if legend[:class].to_s.include?('collapsed')
  end

  def column_width(id)
    page.evaluate_script("document.querySelector('td##{id}').offsetWidth")
  end

  def drag_column_resizer(column_id, distance)
    handle = find("td##{column_id} .ui-resizable-e")
    page.driver.browser.action.click_and_hold(handle.native).move_by(distance, 0).release.perform
  end
end
