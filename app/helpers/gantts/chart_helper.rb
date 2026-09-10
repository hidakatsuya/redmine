# frozen_string_literal: true

module Gantts
  # Adapts view models to ERB attributes, CSS coordinates and Stimulus input data.
  module ChartHelper
    RELATION_STYLES = {
      IssueRelation::TYPE_BLOCKS => { landscape_margin: 16, color: '#fa5252' }.freeze,
      IssueRelation::TYPE_PRECEDES => { landscape_margin: 20, color: '#228be6' }.freeze
    }.freeze

    ROW_SUBJECT_CLASSES = {
      project: 'project-name',
      version: 'version-name',
      issue: 'issue-subject'
    }.freeze

    SELECTED_COLUMN_WIDTH = 50

    def gantt_chart_tag(chart, project: nil, &)
      selected_columns_width = chart.selected_columns.size * SELECTED_COLUMN_WIDTH
      data_attributes = {
        controller: 'gantt--chart',
        action: %w(
          gantt--options:toggle-display@document->gantt--chart#handleOptionsDisplay
          gantt--options:toggle-relations@document->gantt--chart#handleOptionsRelations
          gantt--options:toggle-progress@document->gantt--chart#handleOptionsProgress
          gantt--column:resize->gantt--chart#handleColumnResize
          gantt:row-toggled->gantt--chart#handleLayoutInvalidated
          gantt:sidebar-resized->gantt--chart#handleSidebarResized
          resize@window->gantt--chart#handleWindowResize
          beforeprint@window->gantt--chart#handleBeforePrint
          afterprint@window->gantt--chart#handleAfterPrint
        ).join(' '),
        'gantt--chart-issue-relation-types-value': RELATION_STYLES.to_json,
        'gantt--chart-relations-value': chart.relations.map(&:to_h).to_json,
        'gantt--chart-column-widths-value': chart.selected_columns.map { SELECTED_COLUMN_WIDTH }.to_json,
        'gantt--chart-show-selected-columns-value': chart.show_selected_columns? ? 'true' : 'false',
        'gantt--chart-show-relations-value': chart.show_relations? ? 'true' : 'false',
        'gantt--chart-show-progress-value': chart.show_progress_line? ? 'true' : 'false'
      }
      styles = [
        "--gantt-row-height: #{chart.row_height}px", "--gantt-header-rows: #{chart.header_layers}",
        "--gantt-row-count: #{chart.row_count}",
        "--gantt-day-width: #{chart.day_width}px", "--gantt-selected-columns-width: #{selected_columns_width}px",
        "--gantt-selected-columns-count: #{chart.selected_columns.size}",
        "--gantt-selected-columns-template: #{chart.selected_columns.map { "#{SELECTED_COLUMN_WIDTH}px" }.join(' ')}",
        "--gantt-subject-width: #{chart.sidebar_subject_width}px", "--gantt-timeline-width: #{chart.timeline_width}px"
      ].join('; ')
      tag.div class: ['gantt', { 'is-showing-columns': chart.show_selected_columns? }], style: styles,
              data: data_attributes.merge('gantt-project-id': project&.id), &
    end

    def gantt_scale_segment_tag(segment, &)
      classes = "gantt__scale-segment gantt__scale-segment--#{segment.kind.to_s.tr('_', '-')}"
      classes << ' is-non-working-day' if segment.non_working_day
      tag.div class: classes, style: gantt_scale_segment_style(segment), title: segment.title, &
    end

    def gantt_scale_segment_style(segment)
      "--gantt-segment-start: #{segment.start_offset}; --gantt-segment-span: #{segment.span}; " \
        "--gantt-scale-layer: #{segment.layer}"
    end

    def gantt_row_tag(row, &)
      tag.div id: "gantt-row-#{row.row_key}",
              class: ['gantt__row', "gantt__row--#{row.kind}"],
              style: gantt_row_style(row),
              data: {
                'gantt--chart-target': 'row',
                'gantt--subjects-target': 'row',
                row_key: row.row_key,
                parent_row_key: row.parent_row_key.to_s,
                kind: row.kind,
                progress_state: gantt_row_progress_state(row)
              }, &
    end

    def gantt_row_subject_tag(row, &)
      tag.div id: row.row_key,
              class: [
                'gantt__subject',
                "gantt__subject--#{row.kind}",
                ROW_SUBJECT_CLASSES.fetch(row.kind),
                { 'is-open': row.expandable?, hascontextmenu: row.context_menu? }
              ], &
    end

    def gantt_row_expander_tag(row)
      if row.expandable?
        tag.button sprite_icon('angle-down', rtl: true),
                   type: 'button', class: ['gantt__expander', 'icon', 'icon-expanded'],
                   aria: { expanded: true }, data: { action: 'click->gantt--subjects#toggleRow' }
      else
        tag.span '', class: 'gantt__expander-placeholder', aria: { hidden: true }
      end
    end

    def gantt_issue_subject_tag(row, &)
      classes = +'gantt__subject-text'
      classes << ' issue-overdue' if row.overdue?
      classes << ' issue-behind-schedule' if row.behind_schedule?
      classes << ' issue-closed' if row.closed?
      classes << ' behind-start-date' if row.behind_start_date?
      classes << ' over-end-date' if row.over_end_date?
      tag.span class: classes, title: row.subject, &
    end

    def gantt_row_style(row)
      "--gantt-depth: #{row.depth}"
    end

    def gantt_column_value_tag(column, issue)
      # Column classes are shared by every issue row in this rendering.
      @gantt_column_value_classes ||= {}
      classes = @gantt_column_value_classes[column] ||= class_names('gantt__cell-value', column.css_classes)
      tag.div column_content(column, issue), class: classes
    end

    def gantt_row_progress_state(row)
      return 'none' if row.project?
      return 'closed' if row.closed?
      return 'over-end' if row.over_end_date?
      return 'behind-start' if row.behind_start_date?

      'todo'
    end

    def gantt_schedule_bar_tag(row)
      tag.div class: [*gantt_schedule_base_classes(row), 'gantt__bar', 'task_todo'],
              id: "task-todo-#{row.row_key}", style: gantt_schedule_bar_style(row.schedule),
              data: { 'gantt--chart-target': 'todoBar', row_key: row.row_key }
    end

    def gantt_schedule_late_bar_tag(row)
      tag.div class: [*gantt_schedule_base_classes(row), 'gantt__bar', 'gantt__bar--late', 'task_late'],
              style: "--gantt-start-unit: #{row.schedule.bar_start_offset}; --gantt-end-unit: #{row.schedule.late_offset}"
    end

    def gantt_schedule_done_bar_tag(row, day_width:)
      end_offset = (row.schedule.progress_offset * day_width).floor.to_f / day_width
      tag.div class: [*gantt_schedule_base_classes(row), 'gantt__bar', 'gantt__bar--done', 'task_done'],
              id: "task-done-#{row.row_key}",
              style: "--gantt-start-unit: #{row.schedule.bar_start_offset}; --gantt-end-unit: #{end_offset}",
              data: { 'gantt--chart-target': 'doneBar', row_key: row.row_key }
    end

    def gantt_schedule_start_marker_tag(row)
      tag.div class: [*gantt_schedule_base_classes(row), 'gantt__marker', 'gantt__marker--start', 'starting'],
              style: "--gantt-marker-unit: #{row.schedule.start_offset}"
    end

    def gantt_schedule_end_marker_tag(row)
      tag.div class: [*gantt_schedule_base_classes(row), 'gantt__marker', 'gantt__marker--end', 'ending'],
              style: "--gantt-marker-unit: #{row.schedule.end_offset}"
    end

    def gantt_schedule_label_tag(schedule)
      tag.span schedule.label, style: "--gantt-label-unit: #{schedule.bar_end_offset || 0}"
    end

    def gantt_schedule_bar_style(schedule)
      ["--gantt-start-unit: #{schedule.bar_start_offset}", "--gantt-end-unit: #{schedule.bar_end_offset}"].join('; ')
    end

    private

    def gantt_schedule_base_classes(row)
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
