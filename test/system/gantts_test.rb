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
    assert_no_selector '.gantt__column-header', visible: true

    find('#draw_selected_columns').check

    assert_selector '.gantt.is-showing-columns'
    assert sidebar_width > 330
    assert_selector '.gantt__column-header', count: 4
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

  test 'selected columns can be resized independently' do
    visit_gantt
    expand_options
    find('#draw_selected_columns').check

    width_before = column_width(0)
    drag_column_resizer(0, 80)

    assert_operator column_width(0), :>, width_before
  end

  test 'information and timeline cells share a row' do
    visit_gantt
    expand_options

    alignment = page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector('.gantt__row[data-row-key="project-1"]')
        const information = row.querySelector('.gantt__row-information')
        const timeline = row.querySelector('.gantt__timeline-cell')
        const informationHeader = document.querySelector('.gantt__header-information')
        const timelineHeader = document.querySelector('.gantt__header-timeline')

        return {
          informationTop: information.getBoundingClientRect().top,
          timelineTop: timeline.getBoundingClientRect().top,
          informationHeaderHeight: informationHeader.getBoundingClientRect().height,
          timelineHeaderHeight: timelineHeader.getBoundingClientRect().height
        }
      })()
    JS

    assert_in_delta alignment['timelineTop'], alignment['informationTop'], 1
    assert_in_delta alignment['timelineHeaderHeight'], alignment['informationHeaderHeight'], 1
  end

  test 'sidebar header stays above timeline header while horizontally scrolling' do
    visit_gantt
    expand_options

    header = page.evaluate_script(<<~JS)
      (() => {
        const viewport = document.querySelector('.gantt__viewport')
        const sidebarHeader = document.querySelector('.gantt__header-information')
        viewport.scrollLeft = 800

        const rect = sidebarHeader.getBoundingClientRect()

        return {
          sidebarLeft: rect.left,
          viewportLeft: viewport.getBoundingClientRect().left,
          sidebarZ: getComputedStyle(sidebarHeader).zIndex
        }
      })()
    JS

    assert_in_delta header['viewportLeft'], header['sidebarLeft'], 1
    assert_equal '35', header['sidebarZ']
  end

  test 'retains compact rows and document scrolling' do
    visit_gantt

    dimensions = page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector('.gantt__row')
        const viewport = document.querySelector('.gantt__viewport')
        return [row.getBoundingClientRect().height, getComputedStyle(viewport).maxBlockSize,
                getComputedStyle(document.querySelector('.gantt__header')).position]
      })()
    JS

    assert_equal [20, 'none', 'relative'], dimensions
  end

  test 'sidebar blank areas cover the timeline while horizontally scrolling' do
    visit_gantt
    expand_options

    [false, true].each do |columns|
      find('#draw_selected_columns').set(columns)
      coverage = page.evaluate_script(<<~JS)
        (() => {
          const viewport = document.querySelector('.gantt__viewport')
          const body = document.querySelector('.gantt__body')
          const background = document.querySelector('.gantt__sidebar-background')
          body.scrollIntoView({block: 'end'})
          viewport.scrollLeft = 200
          const rect = background.getBoundingClientRect()
          const bodyRect = body.getBoundingClientRect()
          const x = rect.right - 5
          return {
            scroll: viewport.scrollLeft,
            left: rect.left,
            viewportLeft: viewport.getBoundingClientRect().left,
            topCovered: document.elementFromPoint(x, bodyRect.top + 3) === background,
            bottomCovered: document.elementFromPoint(x, bodyRect.bottom - 5) === background
          }
        })()
      JS
      assert_operator coverage['scroll'], :>, 0
      assert_in_delta coverage['viewportLeft'], coverage['left'], 1, coverage.inspect
      assert coverage['topCovered'], 'timeline must not show above the first row'
      assert coverage['bottomCovered'], 'timeline must not show below the last row'
    end
  end

  test 'scale boundaries use a single horizontal border' do
    visit '/projects/ecookbook/issues/gantt?zoom=4'
    borders = page.evaluate_script(<<~JS)
      (() => {
        const layers = Array.from(document.querySelectorAll('.gantt__scale-row'))
        const border = (element, side) => parseFloat(getComputedStyle(element)[side])
        return layers.slice(1).map((layer, index) =>
          border(layers[index], 'borderBottomWidth') +
          border(layers[index].firstElementChild, 'borderBottomWidth') +
          border(layer, 'borderTopWidth') + border(layer.firstElementChild, 'borderTopWidth'))
      })()
    JS
    assert_equal [1, 1, 1], borders
  end

  test 'context menu and tooltip interactions' do
    visit_gantt

    issue1_subject_row = find('#issue-1')
    issue1_tooltip = find('div.tooltip[data-row-key="issue-1"]')

    # Tooltip for issue task bar
    issue1_tooltip.hover

    within issue1_tooltip do
      assert_selector 'span.tip', :text => issue1_subject_row.first('a.issue').text, :visible => false
    end

    # Context menu for issue subject
    issue1_subject_row.right_click

    assert_selector '#context-menu'
    assert_selector '#context-menu a.icon-edit'

    # Click outside the context menu to close it
    issue1_subject_row.click(x: -1, y: 0)
    assert_no_selector '#context-menu'

    # Context menu for issue task bar
    issue1_tooltip.right_click

    assert_selector '#context-menu'
    assert_selector '#context-menu a.icon-edit'
  end

  test 'printing keeps rows on the same continuous plane as relation lines' do
    visit_gantt
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', :media => 'print')
    page.execute_script("window.dispatchEvent(new Event('beforeprint'))")

    assert_selector '.gantt.is-printing'
    positions = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.gantt__row:not(.is-hidden)')).map(row => ({
        position: getComputedStyle(row).position,
        top: row.offsetTop,
        height: row.offsetHeight
      }))
    JS
    assert positions.all? {|row| row['position'] == 'absolute'}
    positions.each_cons(2) do |previous, current|
      assert_equal previous['top'] + previous['height'], current['top']
    end
    assert_selector '#gantt_draw_area path', minimum: 1

    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', :media => '')
    page.execute_script("window.dispatchEvent(new Event('afterprint'))")
    assert_no_selector '.gantt.is-printing'
    assert_equal 'static', page.evaluate_script("getComputedStyle(document.querySelector('.gantt__row')).position")
  ensure
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', :media => '')
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
    page.evaluate_script("document.querySelector('.gantt__header-information').offsetWidth")
  end

  def drag_splitter(distance)
    handle = find('.gantt__splitter')
    page.driver.browser.action.click_and_hold(handle.native).move_by(distance, 0).release.perform
  end

  def column_width(index)
    page.evaluate_script("document.querySelectorAll('.gantt__column-header')[#{index}].offsetWidth")
  end

  def drag_column_resizer(index, distance)
    handle = all('.gantt__column-resizer')[index]
    page.driver.browser.action.click_and_hold(handle.native).move_by(distance, 0).release.perform
  end
end
