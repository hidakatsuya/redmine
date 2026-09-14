# frozen_string_literal: true

module Redmine
  class Gantt
    # HTML view model for the header, project sections and cross-row connections.
    class Chart
      DEFAULT_SUBJECT_WIDTH = 330

      # Connects two issue bars in the browser's SVG overlay.
      Relation = Struct.new(
        # Source row whose bar end anchors the line.
        :from_row_key,
        # Target row whose bar start receives the arrow.
        :to_row_key,
        # IssueRelation type used to select the line style.
        :type,
        keyword_init: true
      )

      # One horizontal band of the calendar header (month, week or day).
      ScaleLayer = Struct.new(
        # Zero-based vertical position, with months at the top.
        :index,
        # Header cells in chronological order.
        :segments,
        keyword_init: true
      )

      # One calendar header cell; the lowest band's cells also define grid columns.
      ScaleSegment = Struct.new(
        # Header band containing this cell.
        :layer,
        # Visible month, week number, day number or weekday abbreviation.
        :label,
        # First date of the cell, also used by month navigation links.
        :start_on,
        # Days from the chart start to the cell's left edge (zero-based).
        :start_offset,
        # Cell width in days, converted to pixels by CSS.
        :span,
        # Rendering variant: :month, :week, :day_number or :day_name.
        :kind,
        # Whether the day cell and its grid column receive non-working-day shading.
        :non_working_day,
        # Optional tooltip containing the full month name and year.
        :title,
        keyword_init: true
      )

      # First date shown on the timeline.
      attr_reader :date_from
      # Last date shown on the timeline, inclusive.
      attr_reader :date_to
      # Detail level (1-4), controlling header bands and horizontal scale.
      attr_reader :zoom
      # Pixels per day on screen.
      attr_reader :day_width
      # Number of header bands, used to size the information-column headings.
      attr_reader :header_layers
      # ProjectSection objects in display order; each supplies its own rows.
      attr_reader :sections
      # Connections between issue bars, passed to the SVG renderer.
      attr_reader :relations
      # Calendar header bands, from months down to the finest visible scale.
      attr_reader :scale_layers
      # Query columns beside the subject, also retained when columns are hidden.
      attr_reader :selected_columns
      # Full timeline width in pixels, including the horizontally scrolled area.
      attr_reader :timeline_width
      # Initial subject-column width in pixels, before browser resizing.
      attr_reader :sidebar_subject_width
      # Today's right edge in days from date_from, or nil outside the timeline.
      attr_reader :today_offset

      def self.build(gantt, query:)
        new(**Builder.new(gantt, query: query).build)
      end

      def initialize(date_from:, date_to:, zoom:, day_width:, header_layers:, sections:, relations:, scale_layers:,
                     selected_columns:, show_selected_columns:, show_relations:, show_progress_line:,
                     timeline_width:, sidebar_subject_width:, today_offset:, truncated:)
        @date_from = date_from
        @date_to = date_to
        @zoom = zoom
        @day_width = day_width
        @header_layers = header_layers
        @sections = sections
        @relations = relations
        @scale_layers = scale_layers
        @selected_columns = selected_columns
        @show_selected_columns = show_selected_columns
        @show_relations = show_relations
        @show_progress_line = show_progress_line
        @timeline_width = timeline_width
        @sidebar_subject_width = sidebar_subject_width
        @today_offset = today_offset
        @truncated = truncated
        freeze
      end

      def rows
        sections.flat_map(&:rows).freeze
      end

      def row_height
        20
      end

      def row_count
        sections.sum(&:row_count)
      end

      def truncated?
        @truncated
      end

      def show_selected_columns?
        @show_selected_columns
      end

      def show_relations?
        @show_relations
      end

      def show_progress_line?
        @show_progress_line
      end

      def show_today?
        !today_offset.nil?
      end

      # Assembles the calendar header and sections without retaining row view models.
      class Builder
        def initialize(gantt, query:)
          @gantt = gantt
          @query = query
        end

        def build
          date_from = @gantt.date_from
          date_to = @gantt.date_to
          zoom = @gantt.zoom
          day_width = 2**zoom
          dataset = @gantt.dataset
          context = @gantt
          sections = dataset.each_project.map do |project, depth, limit|
            ProjectSection.new(context, project, depth, limit)
          end.freeze
          scale_segments = build_scale_segments(date_from, date_to, zoom)
          {
            date_from: date_from, date_to: date_to, zoom: zoom, day_width: day_width,
            header_layers: header_layers_for(zoom), sections: sections, relations: build_relations,
            scale_layers: scale_layers_for(scale_segments), selected_columns: selected_columns,
            show_selected_columns: @query.draw_selected_columns, show_relations: @query.draw_relations,
            show_progress_line: @query.draw_progress_line,
            timeline_width: ((date_to - date_from + 1) * day_width).to_i,
            sidebar_subject_width: DEFAULT_SUBJECT_WIDTH,
            today_offset: today_offset_for(date_from, date_to), truncated: @gantt.dataset.truncated?
          }
        end

        private

        # Only connect issue bars admitted by the chart-wide row limit.
        def build_relations
          visible_keys = @gantt.dataset.each_row.filter_map do |record, _depth, key, _parent|
            key if record.is_a?(::Issue)
          end.to_set
          @gantt.dataset.relations.values.flatten.filter_map do |relation|
            from_key = "issue-#{relation.issue_from_id}"
            to_key = "issue-#{relation.issue_to_id}"
            next unless visible_keys.include?(from_key) && visible_keys.include?(to_key)

            Relation.new(from_row_key: from_key, to_row_key: to_key, type: relation.relation_type).freeze
          end.freeze
        end

        # Calendar cells above the timeline; zoom selects month/week/day bands.
        def build_scale_segments(date_from, date_to, zoom)
          segments = []
          month = date_from
          @gantt.months.times do
            segments << ScaleSegment.new(layer: 0, label: "#{month.year}-#{month.month}",
                                         title: "#{::I18n.t('date.month_names')[month.month]} #{month.year}",
                                         start_on: month, start_offset: (month - date_from).to_i,
                                         span: ((month >> 1) - month).to_i,
                                         kind: :month, non_working_day: false).freeze
            month >>= 1
          end
          append_week_segments(segments, date_from, date_to, 1) if zoom > 1
          append_day_segments(segments, date_from, date_to, zoom > 3 ? 2 : nil, :day_number) if zoom > 3
          append_day_segments(segments, date_from, date_to, zoom > 3 ? 3 : 2, :day_name) if zoom > 2
          segments.freeze
        end

        # Week-number cells start on Mondays; an initial partial week has no label.
        def append_week_segments(segments, date_from, date_to, layer)
          week = date_from.cwday == 1 ? date_from : date_from + (7 - date_from.cwday + 1)
          while week <= date_to
            segments << ScaleSegment.new(layer: layer, label: week.cweek.to_s,
                                         start_on: week, start_offset: (week - date_from).to_i,
                                         span: [7, (date_to - week + 1).to_i].min,
                                         kind: :week, non_working_day: false).freeze
            week += 7
          end
        end

        # Day-number and weekday bands share the same daily grid positions.
        def append_day_segments(segments, date_from, date_to, layer, kind)
          (date_from..date_to).each do |date|
            label = kind == :day_number ? date.day.to_s : ::I18n.t('date.abbr_day_names')[date.wday].first
            segments << ScaleSegment.new(layer: layer, label: label, start_on: date,
                                         start_offset: (date - date_from).to_i, span: 1,
                                         kind: kind, non_working_day: @gantt.non_working_week_days.include?(date.cwday)).freeze
          end
        end

        def scale_layers_for(segments)
          segments.group_by(&:layer).map do |index, values|
            ScaleLayer.new(index: index, segments: values.freeze).freeze
          end.freeze
        end

        # The subject already contains tracker and issue ID, so they are not extra columns.
        def selected_columns
          @query.inline_columns.reject {|column| Redmine::Gantt::UNAVAILABLE_COLUMNS.include?(column.name)}.freeze
        end

        def header_layers_for(zoom)
          1 + [zoom > 1, zoom > 3, zoom > 2].count(true)
        end

        def today_offset_for(date_from, date_to)
          (User.current.today - date_from + 1).to_i if User.current.today.between?(date_from, date_to)
        end
      end
    end
  end
end
