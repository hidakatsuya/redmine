# frozen_string_literal: true

module Gantts
  module ChartHelper
    ROW_SUBJECT_CLASSES = {
      :project => 'project-name',
      :version => 'version-name',
      :issue => 'issue-subject'
    }.freeze

    SELECTED_COLUMN_WIDTH = 96

    def gantt_chart_tag(chart, project: nil, &)
      selected_columns_width = chart.selected_columns.size * SELECTED_COLUMN_WIDTH
      data_attributes = {
        :controller => 'gantt--chart',
        :action => %w(
          gantt--options:toggle-display@document->gantt--chart#handleOptionsDisplay
          gantt--options:toggle-relations@document->gantt--chart#handleOptionsRelations
          gantt--options:toggle-progress@document->gantt--chart#handleOptionsProgress
          gantt--column:resize->gantt--chart#handleColumnResize
          gantt:row-toggled->gantt--chart#handleLayoutInvalidated
          gantt:sidebar-resized->gantt--chart#handleSidebarResized
          resize@window->gantt--chart#handleWindowResize
        ).join(' '),
        'gantt--chart-issue-relation-types-value' => Redmine::Helpers::Gantt::DRAW_TYPES.transform_values(&:symbolize_keys).to_json,
        'gantt--chart-relations-value' => chart.relations.map(&:to_h).to_json,
        'gantt--chart-column-widths-value' => chart.selected_columns.map { SELECTED_COLUMN_WIDTH }.to_json,
        'gantt--chart-show-selected-columns-value' => chart.show_selected_columns? ? 'true' : 'false',
        'gantt--chart-show-relations-value' => chart.show_relations? ? 'true' : 'false',
        'gantt--chart-show-progress-value' => chart.show_progress_line? ? 'true' : 'false'
      }
      styles = [
        "--gantt-row-height: #{chart.row_height}px", "--gantt-header-rows: #{chart.header_layers}",
        "--gantt-day-width: #{chart.day_width}px", "--gantt-selected-columns-width: #{selected_columns_width}px",
        "--gantt-selected-columns-count: #{chart.selected_columns.size}",
        "--gantt-selected-columns-template: #{chart.selected_columns.map { "#{SELECTED_COLUMN_WIDTH}px" }.join(' ')}",
        "--gantt-subject-width: #{chart.sidebar_subject_width}px", "--gantt-timeline-width: #{chart.timeline_width}px"
      ].join('; ')
      tag.div(:class => ['gantt', {'is-showing-columns': chart.show_selected_columns?}], :style => styles,
              :data => data_attributes.merge('gantt-project-id': project&.id), &)
    end

    def gantt_scale_segment_css_classes(segment)
      [
        'gantt__scale-segment',
        "gantt__scale-segment--#{segment.kind.to_s.tr('_', '-')}",
        {'is-non-working-day': segment.non_working_day}
      ]
    end

    def gantt_scale_segment_style(segment)
      ["--gantt-segment-start: #{segment.start_offset}", "--gantt-segment-span: #{segment.span}",
       "--gantt-scale-layer: #{segment.layer}"].join('; ')
    end

    def gantt_row_style(row)
      "--gantt-depth: #{row.depth}"
    end

    def gantt_schedule_style(schedule)
      return unless schedule&.visible?

      ["--gantt-start-unit: #{schedule.bar_start_offset}", "--gantt-end-unit: #{schedule.bar_end_offset}"].join('; ')
    end

    def gantt_marker_style(offset)
      "--gantt-marker-unit: #{offset}"
    end

    def gantt_label_style(schedule)
      "--gantt-label-unit: #{schedule.bar_end_offset}" if schedule&.visible?
    end

    def gantt_progress_style(schedule)
      return unless schedule&.progress?

      ["--gantt-start-unit: #{schedule.bar_start_offset}", "--gantt-end-unit: #{schedule.progress_offset}"].join('; ')
    end

    def gantt_late_style(schedule)
      return unless schedule&.late?

      ["--gantt-start-unit: #{schedule.bar_start_offset}", "--gantt-end-unit: #{schedule.late_offset}"].join('; ')
    end

    def gantt_row_subject_tag(row, &)
      tag.div(
        :id => row.row_key,
        :class => [
          'gantt__subject',
          "gantt__subject--#{row.kind}",
          ROW_SUBJECT_CLASSES.fetch(row.kind),
          {'is-open': row.expandable?, hascontextmenu: row.context_menu?}
        ],
        &
      )
    end

    def gantt_row_subject_text_classes(row)
      [
        'gantt__subject-text',
        {
          'project-overdue': row.project? && row.overdue?,
          'version-behind-schedule': row.version? && row.behind_schedule?,
          'version-overdue': row.version? && row.overdue?,
          'version-closed': row.version? && row.closed?,
          'issue-overdue': row.issue? && row.overdue?,
          'issue-behind-schedule': row.issue? && row.behind_schedule?,
          'issue-closed': row.issue? && row.closed?,
          'behind-start-date': !row.project? && row.behind_start_date?,
          'over-end-date': !row.project? && row.over_end_date?
        }
      ]
    end

    def gantt_bar_classes(row)
      [*gantt_bar_base_classes(row), 'gantt__bar', 'task_todo', {hascontextmenu: row.context_menu?}]
    end

    def gantt_done_bar_classes(row)
      [*gantt_bar_base_classes(row), 'gantt__bar', 'gantt__bar--done', 'task_done']
    end

    def gantt_late_bar_classes(row)
      [*gantt_bar_base_classes(row), 'gantt__bar', 'gantt__bar--late', 'task_late']
    end

    def gantt_marker_classes(row, side)
      [*gantt_bar_base_classes(row), 'gantt__marker', "gantt__marker--#{side}", side == :start ? 'starting' : 'ending']
    end

    def gantt_bar_dom_id(row, state)
      "#{state}-#{row.row_key}"
    end

    def gantt_progress_state(row)
      return 'none' if row.project?
      return 'closed' if row.closed?
      return 'over-end' if row.over_end_date?
      return 'behind-start' if row.behind_start_date?

      'todo'
    end

    private

    def gantt_bar_base_classes(row)
      kind =
        if row.issue?
          row.summary? ? 'parent' : 'leaf'
        else
          row.kind.to_s
        end
      ['task', kind]
    end
  end
end
