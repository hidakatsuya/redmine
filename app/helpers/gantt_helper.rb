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

module GanttHelper
  GANTT_ROW_PARTIALS = {
    Redmine::Gantt::ProjectRow => 'gantts/rows/project',
    Redmine::Gantt::VersionRow => 'gantts/rows/version',
    Redmine::Gantt::IssueRow => 'gantts/rows/issue'
  }.freeze

  def gantt_row_partial(row)
    GANTT_ROW_PARTIALS.fetch(row.class)
  end

  SELECTED_COLUMN_WIDTH = 96

  def gantt_zoom_link(gantt, in_or_out)
    case in_or_out
    when :in
      if gantt.zoom < 4
        link_to(
          sprite_icon('zoom-in', l(:text_zoom_in)),
          {:params => request.query_parameters.merge(gantt.params.merge(:zoom => (gantt.zoom + 1)))},
          :class => 'icon icon-zoom-in')
      else
        content_tag(:span, sprite_icon('zoom-in', l(:text_zoom_in)), :class => 'icon icon-zoom-in').html_safe
      end

    when :out
      if gantt.zoom > 1
        link_to(
          sprite_icon('zoom-out', l(:text_zoom_out)),
          {:params => request.query_parameters.merge(gantt.params.merge(:zoom => (gantt.zoom - 1)))},
          :class => 'icon icon-zoom-out')
      else
        content_tag(:span, sprite_icon('zoom-out', l(:text_zoom_out)), :class => 'icon icon-zoom-out').html_safe
      end
    end
  end

  def gantt_chart_tag(query, chart, project: nil, &)
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
      ).join(' '),
      'gantt--chart-issue-relation-types-value': Redmine::Helpers::Gantt::DRAW_TYPES.transform_values(&:symbolize_keys).to_json,
      'gantt--chart-relations-value': chart.relations.map(&:to_h).to_json,
      'gantt--chart-column-widths-value': chart.selected_columns.map { SELECTED_COLUMN_WIDTH }.to_json,
      'gantt--chart-show-selected-columns-value': query.draw_selected_columns ? 'true' : 'false',
      'gantt--chart-show-relations-value': query.draw_relations ? 'true' : 'false',
      'gantt--chart-show-progress-value': query.draw_progress_line ? 'true' : 'false'
    }

    styles = [
      "--gantt-row-height: #{chart.row_height}px",
      "--gantt-header-rows: #{chart.header_layers}",
      "--gantt-day-width: #{chart.day_width}px",
      "--gantt-selected-columns-width: #{selected_columns_width}px",
      "--gantt-selected-columns-count: #{chart.selected_columns.size}",
      "--gantt-selected-columns-template: #{chart.selected_columns.map { "#{SELECTED_COLUMN_WIDTH}px" }.join(' ')}",
      "--gantt-subject-width: #{chart.sidebar_subject_width}px",
      "--gantt-timeline-width: #{chart.timeline_width}px"
    ].join('; ')

    tag.div(class: ['gantt', ('is-showing-columns' if query.draw_selected_columns)],
            style: styles,
            data: data_attributes.merge('gantt-project-id': project&.id), &)
  end

  def gantt_scale_segment_style(segment)
    [
      "--gantt-segment-start: #{segment.start_offset}",
      "--gantt-segment-span: #{segment.span}",
      "--gantt-scale-layer: #{segment.layer}"
    ].join('; ')
  end

  def gantt_row_style(row)
    "--gantt-depth: #{row.depth}"
  end

  def gantt_schedule_style(schedule)
    return unless schedule&.visible?

    [
      "--gantt-start-unit: #{schedule.bar_start_offset}",
      "--gantt-end-unit: #{schedule.bar_end_offset}"
    ].join('; ')
  end

  def gantt_marker_style(offset)
    "--gantt-marker-unit: #{offset}"
  end

  def gantt_label_style(schedule)
    return unless schedule&.visible?

    "--gantt-label-unit: #{schedule.bar_end_offset}"
  end

  def gantt_progress_style(schedule)
    return unless schedule&.progress_offset

    [
      "--gantt-start-unit: #{schedule.bar_start_offset}",
      "--gantt-end-unit: #{schedule.progress_offset}"
    ].join('; ')
  end

  def gantt_late_style(schedule)
    return unless schedule&.late_offset

    [
      "--gantt-start-unit: #{schedule.bar_start_offset}",
      "--gantt-end-unit: #{schedule.late_offset}"
    ].join('; ')
  end

  def gantt_project_row_subject_tag(row)
    gantt_row_subject_tag(
      row,
      gantt_project_subject_content(row),
      gantt_project_subject_css_classes(row),
      ['gantt__subject--project', 'project-name']
    )
  end

  def gantt_version_row_subject_tag(row)
    gantt_row_subject_tag(
      row,
      gantt_version_subject_content(row),
      gantt_version_subject_css_classes(row),
      ['gantt__subject--version', 'version-name']
    )
  end

  def gantt_issue_row_subject_tag(row)
    gantt_row_subject_tag(
      row,
      gantt_issue_subject_content(row),
      gantt_issue_subject_css_classes(row),
      ['gantt__subject--issue', 'issue-subject', 'hascontextmenu']
    )
  end

  def gantt_row_subject_tag(row, content, css_classes, container_classes)
    expander = if row.has_children
                 content_tag(
                   :button,
                   sprite_icon('angle-down', rtl: true),
                   :type => 'button',
                   :class => 'gantt__expander icon icon-expanded',
                   :aria => {:expanded => 'true'},
                   :data => {
                     :action => 'click->gantt--subjects#toggleRow'
                   }
                 )
               else
                 content_tag(:span, '', :class => 'gantt__expander-placeholder', :aria => {:hidden => 'true'})
               end

    container_classes = ['gantt__subject', *container_classes]
    container_classes << 'is-open' if row.has_children
    content_tag(:div, class: container_classes.join(' '), id: gantt_subject_dom_id(row.record)) do
      expander +
        content_tag(:span, content, :class => ['gantt__subject-text', *css_classes].join(' '), :title => row.subject)
    end
  end

  def gantt_row_column_content(row, column)
    return ''.html_safe unless row.issue?

    content_tag(:div, column_content(column, row.record), :class => ['gantt__cell-value', column.css_classes].compact.join(' '))
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

    classes.tap {|values| values[-1] = row.parent? ? 'parent' : 'leaf'}
  end

  def gantt_subject_dom_id(record)
    "#{record.class.name.demodulize.downcase}-#{record.id}"
  end

  def gantt_issue_subject_content(row)
    issue = row.record
    content = +''
    content << sprite_icon('issue') unless issue.assigned_to
    content << assignee_avatar(issue.assigned_to, :size => 13, :class => 'icon-avatar')
    content << link_to_issue(issue)
    content << content_tag(:input, nil, :type => 'checkbox', :name => 'ids[]',
                           :value => issue.id, :style => 'display:none;',
                           :class => 'toggle-selection')
    content.html_safe
  end

  def gantt_version_subject_content(row)
    version = row.record
    content = +''
    content << sprite_icon('package')
    content << link_to_version(version)
    content.html_safe
  end

  def gantt_project_subject_content(row)
    project = row.record
    content = +''
    content << sprite_icon('projects')
    content << link_to_project(project)
    content.html_safe
  end
end
