# frozen_string_literal: true

require_relative '../test_helper'

class GanttHelperTest < Redmine::HelperTest
  include GanttHelper

  test 'navigation parameters use normalized chart values and project scope' do
    project = projects(:projects_001)
    gantt = Redmine::Gantt.new(query: nil, project: project, year: 2026, month: 11, zoom: 3, months: 6)

    assert_equal({ controller: 'gantts', action: 'show', project_id: project,
                   year: 2026, month: 11, zoom: 3, months: 6 }, gantt_params(gantt))
    assert_not_respond_to gantt, :params
    assert_not_respond_to gantt, :common_params
  end

  test 'previous and next navigation cross year boundaries by the displayed period' do
    gantt = Redmine::Gantt.new(query: nil, year: 2026, month: 3, months: 6)

    assert_equal({ year: 2025, month: 9 }, gantt_previous_params(gantt).slice(:year, :month))
    assert_equal({ year: 2026, month: 9 }, gantt_next_params(gantt).slice(:year, :month))
    assert_nil gantt_next_params(gantt)[:project_id]
  end

  test 'month and zoom links can override their own display parameters' do
    gantt = Redmine::Gantt.new(query: nil, year: 2026, month: 11, zoom: 3, months: 6)

    assert_equal gantt_params(gantt).merge(year: 2027, month: 1),
                 gantt_params(gantt, date: Date.new(2027, 1, 1))
    assert_equal gantt_params(gantt).merge(zoom: 4), gantt_params(gantt, zoom: 4)
    assert_equal 3, gantt.zoom
  end
end
