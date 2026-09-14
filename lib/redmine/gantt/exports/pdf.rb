# frozen_string_literal: true

module Redmine
  class Gantt
    module Exports
      # Draws the downloadable PDF with ITCPDF; browser printing uses HTML/CSS instead.
      class PDF < Base
        # Fixed page layout in PDF units, separate from resizable screen columns.
        class Layout
          MAX_CHARACTERS_FOR_SUBJECT = 45
          TOTAL_WIDTH = 280
          LEFT_PANE_WIDTH = 100

          def self.right_pane_width
            TOTAL_WIDTH - LEFT_PANE_WIDTH
          end
        end

        def render
          pdf = ::Redmine::Export::PDF::ITCPDF.new(current_language)
          pdf.SetTitle("#{l(:label_gantt)} #{project}")
          pdf.alias_nb_pages
          pdf.footer_date = format_date(User.current.today)
          pdf.AddPage("L")
          pdf.SetFontStyle('B', 12)
          pdf.SetX(15)
          pdf.RDMCell(Layout::LEFT_PANE_WIDTH, 20, project.to_s)
          pdf.Ln
          pdf.SetFontStyle('B', 9)
          subject_width = Layout::LEFT_PANE_WIDTH
          header_height = 5
          headers_height = header_height
          show_weeks = false
          show_days = false
          if self.months < 7
            show_weeks = true
            headers_height = 2 * header_height
            if self.months < 3
              show_days = true
              headers_height = 3 * header_height
              if self.months < 2
                show_day_num = true
                headers_height = 4 * header_height
              end
            end
          end
          g_width = Layout.right_pane_width
          zoom = g_width / (self.date_to - self.date_from + 1)
          g_height = 120
          t_height = g_height + headers_height
          y_start = pdf.GetY
          # Months headers
          month_f = self.date_from
          left = subject_width
          height = header_height
          self.months.times do
            width = ((month_f >> 1) - month_f) * zoom
            pdf.SetY(y_start)
            pdf.SetX(left)
            pdf.RDMCell(width, height, "#{month_f.year}-#{month_f.month}", "LTR", 0, "C")
            left += width
            month_f >>= 1
          end
          # Weeks headers
          if show_weeks
            left = subject_width
            height = header_height
            if self.date_from.cwday == 1
              week_f = self.date_from
            else
              week_f = self.date_from + (7 - self.date_from.cwday + 1)
              width = (7 - self.date_from.cwday + 1) * zoom-1
              pdf.SetY(y_start + header_height)
              pdf.SetX(left)
              pdf.RDMCell(width + 1, height, "", "LTR")
              left = left + width + 1
            end
            while week_f <= self.date_to
              width = (week_f + 6 <= self.date_to) ? 7 * zoom : (self.date_to - week_f + 1) * zoom
              pdf.SetY(y_start + header_height)
              pdf.SetX(left)
              pdf.RDMCell(width, height, (width >= 5 ? week_f.cweek.to_s : ""), "LTR", 0, "C")
              left += width
              week_f += 7
            end
          end
          # Day numbers headers
          if show_day_num
            left = subject_width
            height = header_height
            day_num = self.date_from
            pdf.SetFontStyle('B', 7)
            (self.date_from..self.date_to).each do |g_date|
              width = zoom
              pdf.SetY(y_start + header_height * 2)
              pdf.SetX(left)
              pdf.SetTextColor(non_working_week_days.include?(g_date.cwday) ? 150 : 0)
              pdf.RDMCell(width, height, day_num.day.to_s, "LTR", 0, "C")
              left += width
              day_num += 1
            end
          end
          # Days headers
          if show_days
            left = subject_width
            height = header_height
            pdf.SetFontStyle('B', 7)
            (self.date_from..self.date_to).each do |g_date|
              width = zoom
              pdf.SetY(y_start + header_height * (show_day_num ? 3 : 2))
              pdf.SetX(left)
              pdf.SetTextColor(non_working_week_days.include?(g_date.cwday) ? 150 : 0)
              pdf.RDMCell(width, height, day_name(g_date.cwday).first, "LTR", 0, "C")
              left += width
            end
          end
          pdf.SetY(y_start)
          pdf.SetX(15)
          pdf.SetTextColor(0)
          pdf.RDMCell(subject_width + g_width - 15, headers_height, "", 1)
          # Tasks
          top = headers_height + y_start
          options = {
            top: top,
            zoom: zoom,
            subject_width: subject_width,
            g_width: g_width,
            indent: 0,
            indent_increment: 5,
            top_increment: 5,
            format: :pdf,
            pdf: pdf
          }
          render_rows(options)
          pdf.Output
        end

        private

        def render_end(options)
          options[:pdf].Line(15, options[:top], Layout::TOTAL_WIDTH, options[:top])
        end

        def pdf_new_page?(options)
          if options[:top] > 180
            options[:pdf].Line(15, options[:top], Layout::TOTAL_WIDTH, options[:top])
            options[:pdf].AddPage("L")
            options[:top] = 15
            options[:pdf].Line(15, options[:top] - 0.1, Layout::TOTAL_WIDTH, options[:top] - 0.1)
          end
        end

        def pdf_subject(params, subject, options={})
          pdf_new_page?(params)
          params[:pdf].SetY(params[:top])
          params[:pdf].SetX(15)
          char_limit = Layout::MAX_CHARACTERS_FOR_SUBJECT - params[:indent]
          params[:pdf].RDMCell(params[:subject_width] - 15, 5,
                               (" " * params[:indent]) +
                                 subject.to_s.sub(/^(.{#{char_limit}}[^\s]*\s).*$/, '\1 (...)'),
                               "LR")
          params[:pdf].SetY(params[:top])
          params[:pdf].SetX(params[:subject_width])
          params[:pdf].RDMCell(params[:g_width], 5, "", "LR")
        end

        def pdf_task(params, coords, markers, label, object)
          cell_height_ratio = params[:pdf].get_cell_height_ratio
          params[:pdf].set_cell_height_ratio(0.1)

          height = 2
          height /= 2 if markers
          # Renders the task bar, with progress and late
          if coords[:bar_start] && coords[:bar_end]
            width = [1, coords[:bar_end] - coords[:bar_start]].max
            params[:pdf].SetY(params[:top] + 1.5)
            params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
            params[:pdf].SetFillColor(200, 200, 200)
            params[:pdf].RDMCell(width, height, "", 0, 0, "", 1)
            if coords[:bar_late_end]
              width = [1, coords[:bar_late_end] - coords[:bar_start]].max
              params[:pdf].SetY(params[:top] + 1.5)
              params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
              params[:pdf].SetFillColor(255, 100, 100)
              params[:pdf].RDMCell(width, height, "", 0, 0, "", 1)
            end
            if coords[:bar_progress_end]
              width = [1, coords[:bar_progress_end] - coords[:bar_start]].max
              params[:pdf].SetY(params[:top] + 1.5)
              params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
              params[:pdf].SetFillColor(90, 200, 90)
              params[:pdf].RDMCell(width, height, "", 0, 0, "", 1)
            end
          end
          # Renders the markers
          if markers
            if coords[:start]
              params[:pdf].SetY(params[:top] + 1)
              params[:pdf].SetX(params[:subject_width] + coords[:start] - 1)
              params[:pdf].SetFillColor(50, 50, 200)
              params[:pdf].RDMCell(2, 2, "", 0, 0, "", 1)
            end
            if coords[:end]
              params[:pdf].SetY(params[:top] + 1)
              params[:pdf].SetX(params[:subject_width] + coords[:end] - 1)
              params[:pdf].SetFillColor(50, 50, 200)
              params[:pdf].RDMCell(2, 2, "", 0, 0, "", 1)
            end
          end
          # Renders the label on the right
          if label
            params[:pdf].SetX(params[:subject_width] + (coords[:bar_end] || 0) + 5)
            params[:pdf].RDMCell(30, 2, label)
          end

          params[:pdf].set_cell_height_ratio(cell_height_ratio)
        end
      end
    end
  end
end
