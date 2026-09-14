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

module Redmine
  # Entry point created by GanttsController for one query and display period.
  #
  # Components below live in lib/redmine/gantt/ unless a path is given:
  # - Dataset: records, hierarchy, row order and limits shared by all outputs.
  # - Chart -> ProjectSection -> Project/Version/Issue (Row): HTML view models.
  # - Schedule: bar endpoints and progress positions in day units.
  # - app/views/gantts/_chart.html.erb: chart layout; chart/ holds row/bar partials.
  # - app/helpers/gantt_helper.rb / gantts/chart_helper.rb: navigation and DOM attributes.
  # - app/javascript/controllers/gantt/: options, folding, resizing and SVG lines.
  # - app/assets/stylesheets/gantt.css: screen layout and browser printing.
  # - Exports::PDF/Image: direct drawing via Dataset and Schedule, separate from HTML.
  class Gantt
    include ERB::Util
    include Redmine::I18n
    include Redmine::Utils::DateCalculation

    UNAVAILABLE_COLUMNS = [:tracker, :id, :subject]

    attr_accessor :truncated
    attr_reader :year_from, :month_from, :date_from, :date_to, :zoom, :months, :max_rows,
                :query, :project

    def initialize(query:, project: nil, year: nil, month: nil, zoom: nil, months: nil,
                   max_rows: Setting.gantt_items_limit.presence&.to_i)
      @query = query
      @project = project
      @max_rows = max_rows
      @truncated = false

      @date_from = resolve_start_date(year, month)
      @year_from = @date_from.year
      @month_from = @date_from.month
      @zoom = normalize_zoom(zoom)
      @months = normalize_months(months)
      @date_to = (@date_from >> @months) - 1

      save_preferences
    end

    def chart
      @chart ||= Redmine::Gantt::Chart.build(self, query: @query)
    end

    def dataset
      @dataset ||= Redmine::Gantt::Dataset.new(query: query, max_rows: max_rows)
    end

    def project_section(project)
      Redmine::Gantt::ProjectSection.build(self, project: project)
    end

    delegate :issues, :projects, :relations, :project_issues, :project_versions, :version_issues,
             :number_of_rows, :number_of_rows_on_project, to: :dataset

    class << self
      delegate :sort_issues!, :sort_versions!, :sort_issue_logic, to: :'Redmine::Gantt::Dataset'
    end

    def to_pdf
      export = Redmine::Gantt::Exports::PDF.new(self)
      export.render
    ensure
      @truncated = export.truncated if export
    end

    if Object.const_defined?(:MiniMagick)
      def to_image(format='PNG')
        export = Redmine::Gantt::Exports::Image.new(self)
        export.render(format)
      ensure
        @truncated = export.truncated if export
      end
    end

    private

    def resolve_start_date(year, month)
      return User.current.today.beginning_of_month unless year && year.to_i.positive?

      month = (month || 1).to_i
      month = 1 unless month.between?(1, 12)
      Date.civil(year.to_i, month, 1)
    end

    def normalize_zoom(zoom)
      zoom = (zoom || User.current.pref[:gantt_zoom]).to_i
      zoom.between?(1, 4) ? zoom : 2
    end

    def normalize_months(months)
      months = (months || User.current.pref[:gantt_months]).to_i
      months.between?(1, Setting.gantt_months_limit.to_i) ? months : 6
    end

    def save_preferences
      return unless User.current.logged?

      preference = User.current.pref
      return if preference[:gantt_zoom] == zoom && preference[:gantt_months] == months

      preference[:gantt_zoom] = zoom
      preference[:gantt_months] = months
      preference.save
    end
  end
end
