module Redmine
  module Gantt
    class ScheduleBuilder
      def initialize(gantt)
        @gantt = gantt
      end

      def build(start_on:, end_on:, progress:, markers:, label:)
        coords = coordinates(start_on, end_on, progress)

        Schedule.new(
          :start_on => start_on,
          :end_on => end_on,
          :visible_start => visible_date(start_on, @gantt.date_from),
          :visible_end => visible_date(end_on, @gantt.date_to),
          :progress_end => offset_to_date(coords[:bar_progress_end]),
          :late_end => offset_to_date(coords[:bar_late_end]),
          :show_start_marker => markers && coords[:start].present?,
          :show_end_marker => markers && coords[:end].present?,
          :label => label,
          :start_offset => coords[:start],
          :end_offset => coords[:end],
          :bar_start_offset => coords[:bar_start],
          :bar_end_offset => coords[:bar_end],
          :progress_offset => coords[:bar_progress_end],
          :late_offset => coords[:bar_late_end]
        )
      end

      private

      def coordinates(start_date, end_date, progress)
        coords = {}
        if start_date && end_date && start_date <= @gantt.date_to && end_date >= @gantt.date_from
          if start_date >= @gantt.date_from
            coords[:start] = start_date - @gantt.date_from
            coords[:bar_start] = start_date - @gantt.date_from
          else
            coords[:bar_start] = 0
          end

          if end_date <= @gantt.date_to
            coords[:end] = end_date - @gantt.date_from + 1
            coords[:bar_end] = end_date - @gantt.date_from + 1
          else
            coords[:bar_end] = @gantt.date_to - @gantt.date_from + 1
          end

          if progress
            progress_date = calc_progress_date(start_date, end_date, progress)
            if progress_date > @gantt.date_from && progress_date > start_date
              coords[:bar_progress_end] =
                if progress_date < @gantt.date_to
                  progress_date - @gantt.date_from
                else
                  @gantt.date_to - @gantt.date_from + 1
                end
            end

            if progress_date <= User.current.today
              late_date = [User.current.today, end_date].min + 1
              if late_date > @gantt.date_from && late_date > start_date
                coords[:bar_late_end] =
                  if late_date < @gantt.date_to
                    late_date - @gantt.date_from
                  else
                    @gantt.date_to - @gantt.date_from + 1
                  end
              end
            end
          end
        end

        coords.transform_values!(&:to_i)
        coords
      end

      def calc_progress_date(start_date, end_date, progress)
        start_date + (end_date - start_date + 1) * (progress / 100.0)
      end

      def visible_date(date, fallback)
        return unless date

        [date, fallback].max
      end

      def offset_to_date(offset)
        return unless offset

        @gantt.date_from + offset
      end
    end
  end
end
