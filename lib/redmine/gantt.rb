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
  # Simple class to handle gantt chart data
  class Gantt
    include ERB::Util
    include Redmine::I18n
    include Redmine::Utils::DateCalculation

    # Relation types that are rendered
    DRAW_TYPES = {
      IssueRelation::TYPE_BLOCKS   => {
        :landscape_margin => 16,
        :color => '#fa5252' # oc-red-6
      },
      IssueRelation::TYPE_PRECEDES => {
        :landscape_margin => 20,
        :color => '#228be6' # oc-blue-6
      }
    }.freeze

    UNAVAILABLE_COLUMNS = [:tracker, :id, :subject]

    attr_accessor :truncated
    attr_reader :year_from, :month_from, :date_from, :date_to, :zoom, :months, :max_rows,
                :query, :project

    def initialize(query:, project: nil, year: nil, month: nil, zoom: nil, months: nil,
                   max_rows: Setting.gantt_items_limit.presence&.to_i)
      @query = query
      @project = project
      if year && year.to_i >0
        @year_from = year.to_i
        if month && month.to_i >=1 && month.to_i <= 12
          @month_from = month.to_i
        else
          @month_from = 1
        end
      else
        @month_from ||= User.current.today.month
        @year_from ||= User.current.today.year
      end
      zoom = (zoom || User.current.pref[:gantt_zoom]).to_i
      @zoom = (zoom > 0 && zoom < 5) ? zoom : 2
      months = (months || User.current.pref[:gantt_months]).to_i
      @months = (months > 0 && months < Setting.gantt_months_limit.to_i + 1) ? months : 6
      # Save gantt parameters as user preference (zoom and months count)
      if User.current.logged? &&
           (@zoom   != User.current.pref[:gantt_zoom] ||
            @months != User.current.pref[:gantt_months])
        User.current.pref[:gantt_zoom], User.current.pref[:gantt_months] = @zoom, @months
        User.current.preference.save
      end
      @date_from = Date.civil(@year_from, @month_from, 1)
      @date_to = (@date_from >> @months) - 1
      @truncated = false
      @max_rows = max_rows
    end

    def chart
      @chart ||= Redmine::Gantt::Chart.build(self, :query => @query)
    end

    def common_params
      {:controller => 'gantts', :action => 'show', :project_id => @project}
    end

    def params
      common_params.merge({:zoom => zoom, :year => year_from,
                           :month => month_from, :months => months})
    end

    def params_previous
      common_params.merge({:year => (date_from << months).year,
                           :month => (date_from << months).month,
                           :zoom => zoom, :months => months})
    end

    def params_next
      common_params.merge({:year => (date_from >> months).year,
                           :month => (date_from >> months).month,
                           :zoom => zoom, :months => months})
    end

    def dataset
      @dataset ||= Redmine::Gantt::Dataset.new(:query => query, :max_rows => max_rows)
    end

    def project_section(project)
      Redmine::Gantt::ProjectSection.build(self, :project => project)
    end

    delegate :issues, :projects, :relations, :project_issues, :project_versions, :version_issues,
             :number_of_rows, :number_of_rows_on_project, :to => :dataset

    class << self
      delegate :sort_issues!, :sort_versions!, :sort_issue_logic, :to => :'Redmine::Gantt::Dataset'
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
  end
end
