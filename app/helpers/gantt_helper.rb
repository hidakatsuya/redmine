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

  def gantt_chart_table_tag(query, &)
    data_attributes = {
      controller: 'gantt--chart',
      action: %w(
        gantt--options:toggle-display@window->gantt--chart#handleOptionsDisplay
        gantt--options:toggle-relations@window->gantt--chart#handleOptionsRelations
        gantt--options:toggle-progress@window->gantt--chart#handleOptionsProgress
        gantt--tree:changed->gantt--chart#handleTreeChanged
      ).join(' '),
      'gantt--chart-issue-relation-types-value': h(Redmine::Helpers::Gantt::DRAW_TYPES.to_json),
      'gantt--chart-unavailable-columns-value': h(Redmine::Helpers::Gantt::UNAVAILABLE_COLUMNS.map(&:to_s).to_json),
      'gantt--chart-show-selected-columns-value': query.draw_selected_columns ? 'true' : 'false',
      'gantt--chart-show-relations-value': query.draw_relations ? 'true' : 'false',
      'gantt--chart-show-progress-value': query.draw_progress_line ? 'true' : 'false'
    }

    tag.table(class: 'gantt-table', data: data_attributes, &)
  end
end
