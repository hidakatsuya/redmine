# frozen_string_literal: true

module Gantts
  module ChartHelper
    GANTT_ROW_PARTIALS = {
      Redmine::Gantt::Project => 'gantts/chart/rows/project',
      Redmine::Gantt::Version => 'gantts/chart/rows/version',
      Redmine::Gantt::Issue => 'gantts/chart/rows/issue'
    }.freeze

    SELECTED_COLUMN_WIDTH = 96

    def gantt_row_partial(row)
      GANTT_ROW_PARTIALS.fetch(row.class)
    end

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
      tag.div(:class => ['gantt', ('is-showing-columns' if chart.show_selected_columns?)], :style => styles,
              :data => data_attributes.merge('gantt-project-id': project&.id), &)
    end

    def gantt_scale_segment_css_classes(segment)
      classes = ['gantt__scale-segment', "gantt__scale-segment--#{segment.kind.to_s.tr('_', '-')}"]
      classes << 'is-non-working-day' if segment.non_working_day
      classes
    end

    def gantt_scale_segment_content(segment, gantt)
      if segment.kind == :month
        link_to(segment.label, gantt.params.merge(:year => segment.start_on.year, :month => segment.start_on.month), :title => segment.title)
      else
        content_tag(:span, segment.label)
      end
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

    def gantt_project_row_subject_tag(row)
      gantt_row_subject_tag(row, gantt_project_subject_content(row), gantt_project_subject_css_classes(row),
                            ['gantt__subject--project', 'project-name'])
    end

    def gantt_version_row_subject_tag(row)
      gantt_row_subject_tag(row, gantt_version_subject_content(row), gantt_version_subject_css_classes(row),
                            ['gantt__subject--version', 'version-name'])
    end

    def gantt_issue_row_subject_tag(row)
      gantt_row_subject_tag(row, gantt_issue_subject_content(row), gantt_issue_subject_css_classes(row),
                            ['gantt__subject--issue', 'issue-subject', 'hascontextmenu'])
    end

    def gantt_row_subject_tag(row, content, css_classes, container_classes)
      expander =
        if row.expandable?
          content_tag(:button, sprite_icon('angle-down', :rtl => true), :type => 'button',
                      :class => 'gantt__expander icon icon-expanded', :aria => {:expanded => 'true'},
                      :data => {:action => 'click->gantt--subjects#toggleRow'})
        else
          content_tag(:span, '', :class => 'gantt__expander-placeholder', :aria => {:hidden => 'true'})
        end
      classes = ['gantt__subject', *container_classes]
      classes << 'is-open' if row.expandable?
      content_tag(:div, :class => classes.join(' '), :id => row.row_key) do
        expander + content_tag(:span, content, :class => ['gantt__subject-text', *css_classes].join(' '), :title => row.subject)
      end
    end

    def gantt_row_column_content(row, column)
      return ''.html_safe unless row.issue?

      content_tag(:div, column_content(column, row.issue), :class => ['gantt__cell-value', column.css_classes].compact.join(' '))
    end

    def gantt_bar_classes(row)
      [*gantt_bar_base_classes(row), 'gantt__bar', 'task_todo']
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

    def gantt_project_subject_css_classes(row)
      row.overdue? ? ['project-overdue'] : []
    end

    def gantt_version_subject_css_classes(row)
      classes = []
      classes << 'version-behind-schedule' if row.behind_schedule?
      classes << 'version-overdue' if row.overdue?
      classes << 'version-closed' if row.closed?
      classes << 'behind-start-date' if row.behind_start_date?
      classes << 'over-end-date' if row.over_end_date?
      classes
    end

    def gantt_issue_subject_css_classes(row)
      classes = []
      classes << 'issue-overdue' if row.overdue?
      classes << 'issue-behind-schedule' if row.behind_schedule?
      classes << 'issue-closed' if row.closed?
      classes << 'behind-start-date' if row.behind_start_date?
      classes << 'over-end-date' if row.over_end_date?
      classes
    end

    def gantt_bar_base_classes(row)
      classes = ['task', row.kind.to_s]
      return classes unless row.issue?

      classes.tap {|values| values[-1] = row.summary? ? 'parent' : 'leaf'}
    end

    def gantt_issue_subject_content(row)
      issue = row.issue
      content = +''
      content << sprite_icon('issue') unless issue.assigned_to
      content << assignee_avatar(issue.assigned_to, :size => 13, :class => 'icon-avatar')
      content << link_to_issue(issue)
      content << content_tag(:input, nil, :type => 'checkbox', :name => 'ids[]', :value => issue.id,
                             :style => 'display:none;', :class => 'toggle-selection')
      content.html_safe
    end

    def gantt_version_subject_content(row)
      content = +''
      content << sprite_icon('package')
      content << link_to_version(row.version)
      content.html_safe
    end

    def gantt_project_subject_content(row)
      content = +''
      content << sprite_icon('projects')
      content << link_to_project(row.project)
      content.html_safe
    end
  end
end
