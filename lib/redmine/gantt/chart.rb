# frozen_string_literal: true

module Redmine
  module Gantt
    class Chart
      DEFAULT_SUBJECT_WIDTH = 330
      Relation = Struct.new(:from_row_key, :to_row_key, :type, keyword_init: true)
      ScaleSegment = Struct.new(:layer, :label, :start_offset, :span, :css_classes, :title, keyword_init: true)

      attr_reader :date_from, :date_to, :zoom, :day_width, :header_layers, :rows,
                  :relations, :scale_segments, :selected_columns, :timeline_width,
                  :sidebar_subject_width, :today_offset

      def self.build(gantt, query:)
        new(gantt, query:)
      end

      def row_height
        32
      end

      def truncated?
        @truncated
      end

      private

      def initialize(gantt, query:)
        @gantt = gantt
        @query = query
        @rows = []
        populate
      ensure
        @gantt = nil
        @query = nil
      end

      def populate
        @row_count = 0
        @truncated = false

        begin
          ::Project.project_tree(@gantt.projects) {|project, level| append_project(project, level)}
        rescue MaxRowsReached
          @truncated = true
        end

        @date_from = @gantt.date_from
        @date_to = @gantt.date_to
        @zoom = @gantt.zoom
        @day_width = 2**@zoom
        @header_layers = header_layers_for(@zoom)
        @relations = build_relations.freeze
        @scale_segments = build_scale_segments.freeze
        @selected_columns = selected_columns_for(@query).freeze
        @timeline_width = ((@date_to - @date_from + 1) * @day_width).to_i
        @sidebar_subject_width = DEFAULT_SUBJECT_WIDTH
        @today_offset = today_offset_for_chart
        @rows = @rows.freeze
      end

      def append_project(project, level)
        parent_row_key = "project-#{project.parent_id}" if level.positive?
        add_row(project, level, parent_row_key)
        append_issues(@gantt.project_issues(project).select {|issue| issue.fixed_version_id.nil?}, level + 1,
                      "project-#{project.id}")

        versions = @gantt.project_versions(project)
        Redmine::Helpers::Gantt.sort_versions!(versions)
        versions.each {|version| append_version(project, version, level + 1)}
      end

      def append_version(project, version, depth)
        add_row(version, depth, "project-#{project.id}")
        append_issues(@gantt.version_issues(project, version), depth + 1, "version-#{version.id}")
      end

      def append_issues(issues, depth, parent_row_key)
        Redmine::Helpers::Gantt.sort_issues!(issues)
        ancestors = []
        issues.each do |issue|
          ancestors.pop while ancestors.any? && !issue.is_descendant_of?(ancestors.last)
          parent_key = ancestors.last ? "issue-#{ancestors.last.id}" : parent_row_key
          add_row(issue, depth + ancestors.size, parent_key)
          ancestors << issue unless issue.leaf?
        end
      end

      def add_row(record, depth, parent_row_key)
        @row_count += 1
        raise MaxRowsReached if @gantt.max_rows && @row_count > @gantt.max_rows

        @rows << row_class(record).build(record: record, gantt: @gantt, depth: depth, parent_row_key: parent_row_key)
      end

      def row_class(record)
        case record
        when ::Project then Project
        when ::Version then Version
        when ::Issue then Issue
        else
          raise ArgumentError, "Unsupported Gantt row record: #{record.class.name}"
        end
      end

      def selected_columns_for(query)
        query.inline_columns.reject do |column|
          Redmine::Helpers::Gantt::UNAVAILABLE_COLUMNS.include?(column.name)
        end
      end

      def build_relations
        visible_row_keys = @rows.select(&:issue?).index_by(&:row_key)
        @rows.filter_map do |row|
          next unless row.issue?

          @gantt.relations.fetch(row.record.id, []).filter_map do |relation|
            target_key = "issue-#{relation.issue_to_id}"
            next unless visible_row_keys.key?(target_key)

            Relation.new(:from_row_key => row.row_key, :to_row_key => target_key, :type => relation.relation_type)
          end
        end.flatten
      end

      def build_scale_segments
        segments = []
        layer = 0
        month = @date_from
        @gantt.months.times do
          segments << ScaleSegment.new(:layer => layer, :label => "#{month.year}-#{month.month}",
                                       :title => "#{::I18n.t('date.month_names')[month.month]} #{month.year}",
                                       :start_offset => (month - @date_from).to_i,
                                       :span => ((month >> 1) - month).to_i,
                                       :css_classes => %w[gantt__scale-segment gantt__scale-segment--month])
          month >>= 1
        end
        append_week_segments(segments, layer += 1) if show_weeks?
        append_day_segments(segments, layer += 1, 'day-number') if show_day_numbers?
        append_day_segments(segments, layer += 1, 'day-name') if show_days?
        segments
      end

      def append_week_segments(segments, layer)
        week = @date_from.cwday == 1 ? @date_from : @date_from + (7 - @date_from.cwday + 1)
        while week <= @date_to
          segments << ScaleSegment.new(:layer => layer, :label => week.cweek.to_s,
                                       :start_offset => (week - @date_from).to_i,
                                       :span => [7, (@date_to - week + 1).to_i].min,
                                       :css_classes => %w[gantt__scale-segment gantt__scale-segment--week])
          week += 7
        end
      end

      def append_day_segments(segments, layer, suffix)
        (@date_from..@date_to).each do |date|
          label = suffix == 'day-number' ? date.day.to_s : ::I18n.t('date.abbr_day_names')[date.wday]
          segments << ScaleSegment.new(:layer => layer, :label => label,
                                       :start_offset => (date - @date_from).to_i, :span => 1,
                                       :css_classes => day_css_classes(date, suffix))
        end
      end

      def day_css_classes(date, suffix)
        classes = ['gantt__scale-segment', "gantt__scale-segment--#{suffix}"]
        classes << 'is-non-working-day' if @gantt.non_working_week_days.include?(date.cwday)
        classes
      end

      def header_layers_for(zoom)
        1 + [zoom > 1, zoom > 3, zoom > 2].count(true)
      end

      def show_weeks?
        @zoom > 1
      end

      def show_days?
        @zoom > 2
      end

      def show_day_numbers?
        @zoom > 3
      end

      def today_offset_for_chart
        return unless User.current.today.between?(@date_from, @date_to)

        (User.current.today - @date_from + 1).to_i
      end

      MaxRowsReached = Class.new(StandardError)
      private_constant :MaxRowsReached
      private_class_method :new
    end
  end
end
