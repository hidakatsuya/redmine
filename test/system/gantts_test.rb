# frozen_string_literal: true

require_relative '../application_system_test_case'

class GanttsTest < ApplicationSystemTestCase
  setup do
    log_user('jsmith', 'jsmith')
  end

  test 'columns display toggle shows status priority assignee updated' do
    visit_gantt
    expand_options

    assert_no_selector '.gantt.is-showing-columns'
    assert_in_delta 330, sidebar_width, 1
    assert_no_selector '.gantt__column-header[data-column-name="status"]', visible: true
    assert_no_selector '.gantt__column-header[data-column-name="priority"]', visible: true
    assert_no_selector '.gantt__column-header[data-column-name="assigned_to"]', visible: true
    assert_no_selector '.gantt__column-header[data-column-name="updated_on"]', visible: true

    find('#draw_selected_columns').check

    assert_selector '.gantt.is-showing-columns'
    assert sidebar_width > 330
    assert_selector '.gantt__column-header[data-column-name="status"]'
    assert_selector '.gantt__column-header[data-column-name="priority"]'
    assert_selector '.gantt__column-header[data-column-name="assigned_to"]'
    assert_selector '.gantt__column-header[data-column-name="updated_on"]'

    move_available_column_to_selected('due_date')
    assert_selector '.gantt__column-header[data-column-name="due_date"]'

    move_selected_column_to_available('updated_on')
    assert_no_selector '.gantt__column-header[data-column-name="updated_on"]', visible: true
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

  test 'sidebar can be resized by dragging the splitter' do
    visit_gantt
    expand_options

    width_before = sidebar_width
    drag_splitter(80)
    width_after = sidebar_width

    assert width_after > width_before
  end

  test 'sidebar rows align with timeline rows' do
    visit_gantt
    expand_options

    alignment = page.evaluate_script(<<~JS)
      (() => {
        const sidebarRow = document.querySelector('.gantt__row[data-row-key="project-1"]')
        const timelineRow = document.querySelector('.gantt__timeline-row[data-row-key="project-1"]')
        const sidebarHeader = document.querySelector('.gantt__header--sidebar')
        const timelineHeader = document.querySelector('.gantt__header--timeline')

        return {
          sidebarTop: sidebarRow.getBoundingClientRect().top,
          timelineTop: timelineRow.getBoundingClientRect().top,
          sidebarHeaderHeight: sidebarHeader.getBoundingClientRect().height,
          timelineHeaderHeight: timelineHeader.getBoundingClientRect().height
        }
      })()
    JS

    assert_in_delta alignment['timelineTop'], alignment['sidebarTop'], 1
    assert_in_delta alignment['timelineHeaderHeight'], alignment['sidebarHeaderHeight'], 1
  end

  test 'sidebar header stays above timeline header while horizontally scrolling' do
    visit_gantt
    expand_options

    header = page.evaluate_script(<<~JS)
      (() => {
        const viewport = document.querySelector('.gantt__viewport')
        const sidebarHeader = document.querySelector('.gantt__header--sidebar')
        viewport.scrollLeft = 320

        const rect = sidebarHeader.getBoundingClientRect()
        const probeX = rect.right - 12
        const probeY = rect.top + 12
        const element = document.elementFromPoint(probeX, probeY)

        return {
          classes: element ? Array.from(element.classList) : [],
          sidebarZ: getComputedStyle(sidebarHeader).zIndex
        }
      })()
    JS

    assert_includes header['classes'], 'gantt__header--sidebar'
    assert_equal '35', header['sidebarZ']
  end

  test 'hover highlights both sidebar and timeline row' do
    visit_gantt

    find('.gantt__row[data-row-key="issue-1"]').hover

    state = page.evaluate_script(<<~JS)
      (() => {
        const sidebarRow = document.querySelector('.gantt__row[data-row-key="issue-1"]')
        const timelineRow = document.querySelector('.gantt__timeline-row[data-row-key="issue-1"]')
        return {
          sidebarHovered: sidebarRow.classList.contains('is-hovered'),
          timelineHovered: timelineRow.classList.contains('is-hovered')
        }
      })()
    JS

    assert_equal true, state['sidebarHovered']
    assert_equal true, state['timelineHovered']
  end

  test 'context menu and tooltip interactions' do
    visit_gantt

    issue1_subject_row = find('#issue-1')
    issue1_tooltip = find('div.tooltip[data-row-key="issue-1"]')

    # Tooltip for issue task bar
    issue1_tooltip.hover

    within issue1_tooltip do
      assert_selector 'span.tip', visible: false
    end

    # Context menu for issue subject
    issue1_subject_row.right_click

    assert_selector '#context-menu'
    assert_selector '#context-menu a.icon-edit'

    # Click outside the context menu to close it
    issue1_subject_row.click
    assert_no_selector '#context-menu'

  end

  private

  def visit_gantt
    visit '/projects/ecookbook/issues/gantt'
  end

  def expand_options
    legend = find('fieldset#options legend')
    legend.click if legend[:class].to_s.include?('collapsed')
  end

  def sidebar_width
    page.evaluate_script("document.querySelector('.gantt__sidebar').offsetWidth")
  end

  def drag_splitter(distance)
    handle = find('.gantt__splitter')
    page.driver.browser.action.click_and_hold(handle.native).move_by(distance, 0).release.perform
  end

  def move_available_column_to_selected(column_name)
    page.execute_script(<<~JS)
      (() => {
        const available = document.getElementById('available_c')
        const option = Array.from(available.options).find((candidate) => candidate.value === #{column_name.to_json})
        option.selected = true
        moveOptions(available.form.available_c, available.form.selected_c)
      })()
    JS
  end

  def move_selected_column_to_available(column_name)
    page.execute_script(<<~JS)
      (() => {
        const selected = document.getElementById('selected_c')
        const option = Array.from(selected.options).find((candidate) => candidate.value === #{column_name.to_json})
        option.selected = true
        moveOptions(selected.form.selected_c, selected.form.available_c)
      })()
    JS
  end
end
