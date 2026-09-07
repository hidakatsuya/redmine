# frozen_string_literal: true

module Redmine
  class Gantt
    class Chart
      DEFAULT_SUBJECT_WIDTH = 330
      Relation = Struct.new(:from_row_key, :to_row_key, :type, keyword_init: true)
      ScaleLayer = Struct.new(:index, :segments, keyword_init: true)
      ScaleSegment = Struct.new(:layer, :label, :start_on, :start_offset, :span, :kind, :non_working_day, :title, keyword_init: true)

      attr_reader :date_from, :date_to, :zoom, :day_width, :header_layers, :sections, :relations,
                  :scale_layers, :selected_columns, :timeline_width, :sidebar_subject_width,
                  :today_offset

      def self.build(gantt, query:)
        new(**Builder.new(gantt, :query => query).build)
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
          context = @gantt.dup.freeze
          sections = dataset.each_project.map do |project, depth, limit|
            ProjectSection.new(context, project, depth, limit)
          end.freeze
          scale_segments = build_scale_segments(date_from, date_to, zoom)
          {
            :date_from => date_from, :date_to => date_to, :zoom => zoom, :day_width => day_width,
            :header_layers => header_layers_for(zoom), :sections => sections, :relations => build_relations,
            :scale_layers => scale_layers_for(scale_segments), :selected_columns => selected_columns,
            :show_selected_columns => @query.draw_selected_columns, :show_relations => @query.draw_relations,
            :show_progress_line => @query.draw_progress_line,
            :timeline_width => ((date_to - date_from + 1) * day_width).to_i,
            :sidebar_subject_width => DEFAULT_SUBJECT_WIDTH,
            :today_offset => today_offset_for(date_from, date_to), :truncated => @gantt.dataset.truncated?
          }
        end

        private

        def build_relations
          visible_keys = @gantt.dataset.each_row.filter_map do |record, _depth, key, _parent|
            key if record.is_a?(::Issue)
          end.to_set
          @gantt.dataset.relations.values.flatten.filter_map do |relation|
            from_key = "issue-#{relation.issue_from_id}"
            to_key = "issue-#{relation.issue_to_id}"
            next unless visible_keys.include?(from_key) && visible_keys.include?(to_key)

            Relation.new(:from_row_key => from_key, :to_row_key => to_key, :type => relation.relation_type).freeze
          end.freeze
        end

        def build_scale_segments(date_from, date_to, zoom)
          segments = []
          month = date_from
          @gantt.months.times do
            segments << ScaleSegment.new(:layer => 0, :label => "#{month.year}-#{month.month}",
                                         :title => "#{::I18n.t('date.month_names')[month.month]} #{month.year}",
                                         :start_on => month, :start_offset => (month - date_from).to_i,
                                         :span => ((month >> 1) - month).to_i,
                                         :kind => :month, :non_working_day => false).freeze
            month >>= 1
          end
          append_week_segments(segments, date_from, date_to, 1) if zoom > 1
          append_day_segments(segments, date_from, date_to, zoom > 3 ? 2 : nil, :day_number) if zoom > 3
          append_day_segments(segments, date_from, date_to, zoom > 3 ? 3 : 2, :day_name) if zoom > 2
          segments.freeze
        end

        def append_week_segments(segments, date_from, date_to, layer)
          week = date_from.cwday == 1 ? date_from : date_from + (7 - date_from.cwday + 1)
          while week <= date_to
            segments << ScaleSegment.new(:layer => layer, :label => week.cweek.to_s,
                                         :start_on => week, :start_offset => (week - date_from).to_i,
                                         :span => [7, (date_to - week + 1).to_i].min,
                                         :kind => :week, :non_working_day => false).freeze
            week += 7
          end
        end

        def append_day_segments(segments, date_from, date_to, layer, kind)
          (date_from..date_to).each do |date|
            label = kind == :day_number ? date.day.to_s : ::I18n.t('date.day_names')[date.wday].first
            segments << ScaleSegment.new(:layer => layer, :label => label, :start_on => date,
                                         :start_offset => (date - date_from).to_i, :span => 1,
                                         :kind => kind, :non_working_day => @gantt.non_working_week_days.include?(date.cwday)).freeze
          end
        end

        def scale_layers_for(segments)
          segments.group_by(&:layer).map do |index, values|
            ScaleLayer.new(:index => index, :segments => values.freeze).freeze
          end.freeze
        end

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

      private_constant :Builder
      private_class_method :new
    end
  end
end
