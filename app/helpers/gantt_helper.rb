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

  def gantt_row_subject_tag(row)
    css_classes = ["gantt__subject-text", *row.subject_css_classes]
    content = case row.kind
              when :issue
                gantt_issue_subject_content(row)
              when :version
                gantt_version_subject_content(row)
              when :project
                gantt_project_subject_content(row)
              end

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

    content_tag(:div, class: gantt_subject_container_classes(row), id: gantt_subject_dom_id(row.record)) do
      expander +
        content_tag(:span, content, :class => css_classes.join(' '), :title => row.subject)
    end
  end

  def gantt_row_column_content(row, column)
    return ''.html_safe unless row.issue?

    content_tag(:div, column_content(column, row.record), :class => ['gantt__cell-value', column.css_classes].compact.join(' '))
  end

  def gantt_bar_classes(row)
    [*row.bar_css_classes, 'gantt__bar', 'task_todo']
  end

  def gantt_done_bar_classes(row)
    [*row.bar_css_classes, 'gantt__bar', 'gantt__bar--done', 'task_done']
  end

  def gantt_late_bar_classes(row)
    [*row.bar_css_classes, 'gantt__bar', 'gantt__bar--late', 'task_late']
  end

  def gantt_marker_classes(row, side)
    [*row.bar_css_classes, 'gantt__marker', "gantt__marker--#{side}", side == :start ? 'starting' : 'ending']
  end

  def gantt_bar_dom_id(row, state)
    "#{state}-#{row.row_key}"
  end

  def gantt_progress_state(row)
    row.subject_state
  end

  private

  def gantt_subject_container_classes(row)
    classes =
      case row.kind
      when :issue
        ['gantt__subject', 'gantt__subject--issue', 'issue-subject', 'hascontextmenu']
      when :version
        ['gantt__subject', 'gantt__subject--version', 'version-name']
      else
        ['gantt__subject', 'gantt__subject--project', 'project-name']
      end
    classes << 'is-open' if row.has_children
    classes.join(' ')
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
