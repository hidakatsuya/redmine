# frozen_string_literal: true

require_relative 'application_vrt_test_case'

module Vrt
  class GanttsVrt < ApplicationVrtTestCase
    setup do
      log_user('jsmith', 'jsmith')

      travel_to Time.zone.local(2025, 10, 25)
      page.current_window.resize_to(1600, 1200)
    end

    test 'project' do
      capture 'initial' do
        visit '/projects/ecookbook/issues/gantt'
        assert_text 'Gantt'
      end

      capture 'zoom1' do
        click_link 'Zoom out'
        assert_selector 'input#zoom[value="1"]', visible: :all
      end

      capture 'zoom3' do
        click_link 'Zoom in'
        assert_selector 'input#zoom[value="2"]', visible: :all

        click_link 'Zoom in'
        assert_selector 'input#zoom[value="3"]', visible: :all
      end

      capture 'subjects collapsed' do
        # 1.0
        within '#version-2' do
          find('.expander').click
          assert_selector '.icon-collapsed'
        end

        # Private child of eCookbook
        within '.project-name[data-collapse-expand*="project-5"]' do
          find('.expander').click
          assert_selector '.icon-collapsed'
        end

        # eCookbook Subproject 1
        within '.project-name[data-collapse-expand*="project-3"]' do
          find('.expander').click
          assert_selector '.icon-collapsed'
        end
      end

      capture 'zoom4' do
        click_link 'Zoom in'
        assert_selector 'input#zoom[value="4"]', visible: :all
      end

      capture 'zoom4 in September' do
        click_link '« September'
        assert_link '« August'
      end

      capture 'zoom4 in November' do
        select 'November', from: 'month'
        click_link 'Apply'
        assert_link '« October'
      end
    end

    test 'global' do
      capture 'initial' do
        visit '/issues/gantt'
        assert_text 'Gantt'
      end

      capture 'display columns and progress line' do
        within '#options' do
          find('legend').click

          find('#draw_selected_columns').check
          find('#draw_progress_line').check
        end
        assert_selector '.gantt_project_column'
      end

      capture 'hide related issues' do
        within '#options' do
          find('#draw_relations').set(false)
        end
        sleep 1
      end

      capture 'minimize column width' do
        # Collapse options
        first('#options legend').click
        assert_selector '#options.collapsed'

        drag_column_resizer 'td#project', -100
        drag_column_resizer 'td#status', -100
        drag_column_resizer 'td#priority', -100
        drag_column_resizer 'td#assigned_to', -100
        drag_column_resizer 'td#updated_on', -100
        drag_column_resizer 'td.gantt_subjects_column', -300

        assert_selector 'td.gantt_subjects_column[style*="width: 100px"]'
      end

      capture 'minimize window width' do
        page.current_window.then { |w| w.resize_to(500, w.size.last) }
        sleep 1
      end
    end

    private

    def capture(subject)
      yield

      # Collapse sidebar
      unless page.has_selector?('#main.collapsedsidebar')
        find('#main:not(.collapsedsidebar) #sidebar-switch-button').click
        assert_selector '#main.collapsedsidebar'
      end

      test_name = [
        'gantt',
        self.name.to_s.sub(/^test_/, ''),
        subject
      ]
      capture_screenshot test_name.join(' ')
    end

    def drag_column_resizer(column, distance)
      handle = find("#{column} .ui-resizable-e", visible: :all)
      page.driver.browser.action.click_and_hold(handle.native).move_by(distance, 0).release.perform
    end
  end
end
