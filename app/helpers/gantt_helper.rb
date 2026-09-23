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
  class ChartLayout
    # A calendar period displayed in the timeline header.
    Period = Struct.new(
      # The first date of the period, or nil for a leading partial week
      :date,
      # The period width in pixels
      :width,
      # Whether the period represents a non-working day
      :non_working,
      # Whether the period's grid line extends through the chart body
      :spans_body,
      # Whether the period is the last one in its header row
      :last,
      keyword_init: true
    )

    # The full timeline width in pixels
    attr_reader :chart_width
    # The height of one timeline header row in pixels
    attr_reader :header_height
    # The combined height of all visible header rows in pixels
    attr_reader :headers_height
    # The gap between the header and the first chart row in pixels
    attr_reader :content_top
    # The subject pane width used to render its rows in pixels
    attr_reader :subject_width
    # The number of pixels representing one day
    attr_reader :zoom

    def initialize(gantt)
      @gantt = gantt
      @zoom = 2**gantt.zoom
      @subject_width = 330
      @header_height = 18
      @content_top = 8
      @headers_height = header_rows * header_height
      @chart_width = ((gantt.date_to - gantt.date_from + 1) * zoom).to_i
    end

    def content_height
      @content_height ||= [(20 * (@gantt.number_of_rows + 6)) + 150, 206].max
    end

    def pane_height
      headers_height + content_height
    end

    def months
      date = @gantt.date_from

      Array.new(@gantt.months) do |index|
        width = (((date >> 1) - date) * zoom).to_i
        period = Period.new(
          date: date,
          width: width,
          spans_body: !show_weeks?,
          last: index == @gantt.months - 1
        )
        date >>= 1
        period
      end
    end

    def weeks
      return [] unless show_weeks?

      date = @gantt.date_from
      periods = []
      unless date.cwday == 1
        width = (7 - date.cwday + 1) * zoom
        periods << period(
          nil, width,
          spans_body: !show_days?,
          last: date + 7 - date.cwday >= @gantt.date_to
        )
        date += 7 - date.cwday + 1
      end

      while date <= @gantt.date_to
        width = ((date + 6 <= @gantt.date_to) ? 7 * zoom : (@gantt.date_to - date + 1) * zoom).to_i
        periods << period(
          date, width,
          spans_body: !show_days?,
          last: date + 6 >= @gantt.date_to
        )
        date += 7
      end
      periods
    end

    def day_numbers
      return [] unless show_day_numbers?

      day_periods
    end

    def days
      return [] unless show_days?

      day_periods(spans_body: true)
    end

    def today_start
      return unless User.current.today.between?(@gantt.date_from, @gantt.date_to)

      (((User.current.today - @gantt.date_from + 1) * zoom).floor - 1).to_i
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

    private

    def header_rows
      1 + (@gantt.zoom > 1 ? 1 : 0) + (@gantt.zoom > 2 ? 1 : 0) + (@gantt.zoom > 3 ? 1 : 0)
    end

    def day_periods(spans_body: false)
      (@gantt.date_from..@gantt.date_to).map do |date|
        Period.new(
          date: date,
          width: zoom,
          non_working: @gantt.non_working_week_days.include?(date.cwday),
          spans_body: spans_body,
          last: date == @gantt.date_to
        )
      end
    end

    def period(date, width, spans_body: false, last: false)
      Period.new(date: date, width: width, spans_body: spans_body, last: last)
    end
  end

  def gantt_css_variables(variables)
    variables.map {|name, value| "--#{name}:#{value}"}.join(';')
  end

  def gantt_period_style(period)
    gantt_css_variables(
      'gantt-period-width': "#{period.width}px"
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

  def gantt_chart_tag(query, layout, &block)
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

    style = gantt_css_variables(
      'gantt-subject-width': "#{layout.subject_width + 1}px",
      'gantt-header-height': "#{layout.header_height}px",
      'gantt-headers-height': "#{layout.headers_height}px",
      'gantt-chart-width': "#{layout.chart_width}px",
      'gantt-content-top': "#{layout.content_top}px",
      'gantt-content-height': "#{layout.content_height}px",
      'gantt-pane-height': "#{layout.pane_height}px"
    )

    tag.div(class: 'gantt-chart', style: style, data: data_attributes) do
      capture(layout, &block)
    end
  end

  def gantt_column_tag(column_name, min_width: nil, **options, &)
    options[:data] = {
      controller: 'gantt--column',
      action: 'resize@window->gantt--column#handleWindowResize',
      'gantt--column-min-width-value': min_width,
      'gantt-column': column_name
    }
    options[:class] = ['gantt-column', options[:class]]

    options[:style] = gantt_css_variables('gantt-column-width': options.delete(:width)) if options[:width]

    tag.div(**options, &)
  end
end
