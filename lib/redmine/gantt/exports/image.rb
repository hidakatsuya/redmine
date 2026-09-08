# frozen_string_literal: true

module Redmine
  class Gantt
    module Exports
      class Image < Base
        def render(format='PNG')
          date_to = (@date_from >> @months) - 1
          show_weeks = @zoom > 1
          show_days = @zoom > 2
          subject_width = 400
          header_height = 18
          # width of one day in pixels
          zoom = @zoom * 2
          g_width = (@date_to - @date_from + 1) * zoom
          g_height = 20 * number_of_rows + 30
          headers_height = (show_weeks ? 2 * header_height : header_height)
          height = g_height + headers_height
          # TODO: Remove rmagick_font_path in a later version
          unless Redmine::Configuration['rmagick_font_path'].nil?
            Rails.logger.warn(
              'rmagick_font_path option is deprecated. Use minimagick_font_path instead.'
            )
          end
          font_path =
            Redmine::Configuration['minimagick_font_path'].presence ||
              Redmine::Configuration['rmagick_font_path'].presence
          img = MiniMagick::Image.create(".#{format}")
          if Redmine::Configuration['imagemagick_convert_command'].present?
            if MiniMagick.respond_to?(:cli_path)
              MiniMagick.cli_path = File.dirname(Redmine::Configuration['imagemagick_convert_command'])
            else
              Rails.logger.warn(
                'imagemagick_convert_command option is ignored ' \
                'because MiniMagick has removed the option to define a custom path for the binary. ' \
                'Please ensure the convert binary is available in your PATH.'
              )
            end
          end
          MiniMagick.convert do |gc|
            gc.size('%dx%d' % [subject_width + g_width + 1, height])
            gc.xc('white')
            gc.font(font_path) if font_path.present?
            # Subjects
            gc.stroke('transparent')
            subjects(image: gc, top: (headers_height + 20), indent: 4, format: :image)
            # Months headers
            month_f = @date_from
            left = subject_width
            @months.times do
              width = ((month_f >> 1) - month_f) * zoom
              gc.fill('white')
              gc.stroke('grey')
              gc.strokewidth(1)
              gc.draw('rectangle %d,%d %d,%d' % [
                left, 0, left + width, height
              ])
              gc.fill('black')
              gc.stroke('transparent')
              gc.strokewidth(1)
              gc.draw('text %d,%d %s' % [
                left.round + 8, 14, magick_text("#{month_f.year}-#{month_f.month}")
              ])
              left += width
              month_f >>= 1
            end
            # Weeks headers
            if show_weeks
              left = subject_width
              height = header_height
              if @date_from.cwday == 1
                # date_from is monday
                week_f = date_from
              else
                # find next monday after date_from
                week_f = @date_from + (7 - @date_from.cwday + 1)
                width = (7 - @date_from.cwday + 1) * zoom
                gc.fill('white')
                gc.stroke('grey')
                gc.strokewidth(1)
                gc.draw('rectangle %d,%d %d,%d' % [
                  left, header_height, left + width, 2 * header_height + g_height - 1
                ])
                left += width
              end
              while week_f <= date_to
                width = (week_f + 6 <= date_to) ? 7 * zoom : (date_to - week_f + 1) * zoom
                gc.fill('white')
                gc.stroke('grey')
                gc.strokewidth(1)
                gc.draw('rectangle %d,%d %d,%d' % [
                  left.round, header_height, left.round + width, 2 * header_height + g_height - 1
                ])
                gc.fill('black')
                gc.stroke('transparent')
                gc.strokewidth(1)
                gc.draw('text %d,%d %s' % [
                  left.round + 2, header_height + 14, magick_text(week_f.cweek.to_s)
                ])
                left += width
                week_f += 7
              end
            end
            # Days details (week-end in grey)
            if show_days
              left = subject_width
              height = g_height + header_height - 1
              (@date_from..date_to).each do |g_date|
                width =  zoom
                gc.fill(non_working_week_days.include?(g_date.cwday) ? '#eee' : 'white')
                gc.stroke('#ddd')
                gc.strokewidth(1)
                gc.draw('rectangle %d,%d %d,%d' % [
                  left, 2 * header_height, left + width, 2 * header_height + g_height - 1
                ])
                left += width
              end
            end
            # border
            gc.fill('transparent')
            gc.stroke('grey')
            gc.strokewidth(1)
            gc.draw('rectangle %d,%d %d,%d' % [
              0, 0, subject_width + g_width, headers_height
            ])
            gc.stroke('black')
            gc.draw('rectangle %d,%d %d,%d' % [
              0, 0, subject_width + g_width, g_height + headers_height - 1
            ])
            # content
            top = headers_height + 20
            gc.stroke('transparent')
            lines(image: gc, top: top, zoom: zoom,
                  subject_width: subject_width, format: :image)
            # today red line
            if User.current.today.between?(@date_from, date_to)
              gc.stroke('red')
              x = (User.current.today - @date_from + 1) * zoom + subject_width
              gc.draw('line %g,%g %g,%g' % [
                x, headers_height, x, headers_height + g_height - 1
              ])
            end
            gc << img.path
          end
          img.to_blob
        ensure
          img.destroy! if img
        end

        private

        def image_subject(params, subject, options={})
          params[:image].fill('black')
          params[:image].stroke('transparent')
          params[:image].strokewidth(1)
          params[:image].draw('text %d,%d %s' % [
            params[:indent], params[:top] + 2, magick_text(subject)
          ])
        end

        def image_task(params, coords, markers, label, object)
          height = 6
          height /= 2 if markers
          # Renders the task bar, with progress and late
          if coords[:bar_start] && coords[:bar_end]
            params[:image].fill('#aaa')
            params[:image].draw('rectangle %d,%d %d,%d' % [
              params[:subject_width] + coords[:bar_start],
              params[:top],
              params[:subject_width] + coords[:bar_end],
              params[:top] - height
            ])
            if coords[:bar_late_end]
              params[:image].fill('#f66')
              params[:image].draw('rectangle %d,%d %d,%d' % [
                params[:subject_width] + coords[:bar_start],
                params[:top],
                params[:subject_width] + coords[:bar_late_end],
                params[:top] - height
              ])
            end
            if coords[:bar_progress_end]
              params[:image].fill('#00c600')
              params[:image].draw('rectangle %d,%d %d,%d' % [
                params[:subject_width] + coords[:bar_start],
                params[:top],
                params[:subject_width] + coords[:bar_progress_end],
                params[:top] - height
              ])
            end
          end
          # Renders the markers
          if markers
            if coords[:start]
              x = params[:subject_width] + coords[:start]
              y = params[:top] - height / 2
              params[:image].fill('blue')
              params[:image].draw('polygon %d,%d %d,%d %d,%d %d,%d' % [
                x - 4, y,
                x, y - 4,
                x + 4, y,
                x, y + 4
              ])
            end
            if coords[:end]
              x = params[:subject_width] + coords[:end]
              y = params[:top] - height / 2
              params[:image].fill('blue')
              params[:image].draw('polygon %d,%d %d,%d %d,%d %d,%d' % [
                x - 4, y,
                x, y - 4,
                x + 4, y,
                x, y + 4
              ])
            end
          end
          # Renders the label on the right
          if label
            params[:image].fill('black')
            params[:image].draw('text %d,%d %s' % [
              params[:subject_width] + (coords[:bar_end] || 0) + 5,
              params[:top] + 1,
              magick_text(label)
            ])
          end
        end

        # Escape the passed string as a text argument in a draw rule for
        # mini_magick. Note that the returned string is not shell-safe on its own.
        def magick_text(str)
          "'#{str.to_s.gsub(/['\\]/, '\\\\\0')}'"
        end
      end
    end
  end
end
