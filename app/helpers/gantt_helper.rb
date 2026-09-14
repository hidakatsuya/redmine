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
  class GanttChartLayout
    Period = Struct.new(:date, :start, :width, :top, :height, :non_working, keyword_init: true)

    attr_reader :chart_width, :content_height, :header_height, :headers_height, :zoom

    def initialize(gantt)
      @gantt = gantt
      @zoom = 2**gantt.zoom
      @header_height = 18
      @headers_height = header_rows * header_height
      @chart_width = ((gantt.date_to - gantt.date_from + 1) * zoom).to_i

      gantt.render(top: 8, zoom: zoom, g_width: chart_width, subject_width: 330)
      @content_height = [(20 * (gantt.number_of_rows + 6)) + 150, 206].max
    end

    def css_variables
      {
        'gantt-subject-width': '331px',
        'gantt-header-height': "#{header_height}px",
        'gantt-headers-height': "#{headers_height}px",
        'gantt-chart-width': "#{chart_width - 1}px",
        'gantt-content-height': "#{content_height}px",
        'gantt-total-height': "#{headers_height + content_height + 24}px"
      }
    end

    def months
      date = @gantt.date_from
      start = 0

      Array.new(@gantt.months) do
        width = (((date >> 1) - date) * zoom - 1).to_i
        period = Period.new(
          date: date,
          start: start,
          width: width,
          top: 0,
          height: show_weeks? ? header_height : header_height + content_height
        )
        start += width + 1
        date >>= 1
        period
      end
    end

    def weeks
      return [] unless show_weeks?

      date = @gantt.date_from
      start = 0
      periods = []
      unless date.cwday == 1
        width = (7 - date.cwday + 1) * zoom - 1
        periods << period(nil, start, width, header_height, weeks_height)
        start += width + 1
        date += 7 - date.cwday + 1
      end

      while date <= @gantt.date_to
        width = ((date + 6 <= @gantt.date_to) ? 7 * zoom - 1 : (@gantt.date_to - date + 1) * zoom - 1).to_i
        periods << period(date, start, width, header_height, weeks_height)
        start += width + 1
        date += 7
      end
      periods
    end

    def day_numbers
      return [] unless show_day_numbers?

      day_periods(header_height * 2, content_height + header_height * 2 - 1)
    end

    def days
      return [] unless show_days?

      day_periods(show_day_numbers? ? header_height * 3 : header_height * 2,
                  content_height + header_height - 1)
    end

    def today_start
      return unless User.current.today.between?(@gantt.date_from, @gantt.date_to)

      (((User.current.today - @gantt.date_from + 1) * zoom).floor - 1).to_i
    end

    private

    def header_rows
      1 + (@gantt.zoom > 1 ? 1 : 0) + (@gantt.zoom > 2 ? 1 : 0) + (@gantt.zoom > 3 ? 1 : 0)
    end

    def show_weeks?
      @gantt.zoom > 1
    end

    def show_days?
      @gantt.zoom > 2
    end

    def show_day_numbers?
      @gantt.zoom > 3
    end

    def weeks_height
      show_days? ? header_height - 1 : header_height - 1 + content_height
    end

    def day_periods(top, height)
      (@gantt.date_from..@gantt.date_to).each_with_index.map do |date, index|
        Period.new(
          date: date,
          start: index * zoom,
          width: zoom - 1,
          top: top,
          height: height,
          non_working: @gantt.non_working_week_days.include?(date.cwday)
        )
      end
    end

    def period(date, start, width, top, height)
      Period.new(date: date, start: start, width: width, top: top, height: height)
    end
  end

  def gantt_chart_layout(gantt)
    GanttChartLayout.new(gantt)
  end

  def gantt_css_variables(variables)
    variables.map {|name, value| "--#{name}:#{value}"}.join(';')
  end

  def gantt_period_style(period)
    gantt_css_variables(
      'gantt-period-start': "#{period.start}px",
      'gantt-period-width': "#{period.width}px",
      'gantt-period-top': "#{period.top}px",
      'gantt-period-height': "#{period.height}px"
    )
  end

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

  def gantt_chart_tag(query, layout:, &)
    data_attributes = {
      controller: 'gantt--chart',
      # Events emitted by child controllers the chart listens to.
      # - `gantt--options` toggles checkboxes under Options.
      # - `gantt--subjects` reports tree expand/collapse.
      # - Window resize triggers a redraw of progress lines and relations.
      action: %w(
        gantt--options:toggle-display@document->gantt--chart#handleOptionsDisplay
        gantt--options:toggle-relations@document->gantt--chart#handleOptionsRelations
        gantt--options:toggle-progress@document->gantt--chart#handleOptionsProgress
        gantt--subjects:toggle-tree->gantt--chart#handleSubjectTreeChanged
        resize@window->gantt--chart#handleWindowResize
      ).join(' '),
      'gantt--chart-issue-relation-types-value': Redmine::Helpers::Gantt::DRAW_TYPES.to_json,
      'gantt--chart-show-selected-columns-value': query.draw_selected_columns ? 'true' : 'false',
      'gantt--chart-show-relations-value': query.draw_relations ? 'true' : 'false',
      'gantt--chart-show-progress-value': query.draw_progress_line ? 'true' : 'false'
    }

    tag.div(
      class: 'gantt-chart',
      style: gantt_css_variables(layout.css_variables),
      data: data_attributes,
      &
    )
  end

  def gantt_column_tag(column_name, min_width: nil, **options, &)
    options[:data] = {
      controller: 'gantt--column',
      action: 'resize@window->gantt--column#handleWindowResize',
      'gantt--column-min-width-value': min_width,
      'gantt--column-column-value': column_name
    }
    options[:class] = ["gantt_#{column_name}_column", options[:class]]

    options[:style] = gantt_css_variables('gantt-column-width': options.delete(:width)) if options[:width]

    tag.div(**options, &)
  end

  def gantt_subjects_tag(&)
    data_attributes = {
      controller: 'gantt--subjects',
      action: 'gantt--column:resize-column-subjects@document->gantt--subjects#handleResizeColumn'
    }
    tag.div(class: "gantt_subjects", data: data_attributes, &)
  end
end
