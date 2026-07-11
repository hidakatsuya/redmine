# frozen_string_literal: true

require_relative '../../../../test_helper'

class Redmine::Gantt::ScheduleBuilderTest < ActiveSupport::TestCase
  setup do
    @date_from = Date.new(2026, 1, 1)
    @gantt = stub(:date_from => @date_from, :date_to => Date.new(2026, 1, 31))
    @builder = Redmine::Gantt::ScheduleBuilder.new(@gantt)
  end

  test 'clips a schedule to the visible date range' do
    schedule = @builder.build(
      :start_on => @date_from - 2,
      :end_on => @date_from + 40,
      :progress => nil,
      :markers => true,
      :label => 'Clipped'
    )

    assert_equal 0, schedule.bar_start_offset
    assert_equal 31, schedule.bar_end_offset
    assert_not schedule.show_start_marker
    assert_not schedule.show_end_marker
  end

  test 'uses day units instead of pixel coordinates' do
    schedule = @builder.build(
      :start_on => @date_from + 4,
      :end_on => @date_from + 8,
      :progress => 40,
      :markers => true,
      :label => 'Schedule'
    )

    assert_equal 4, schedule.bar_start_offset
    assert_equal 9, schedule.bar_end_offset
    assert_equal 6, schedule.progress_offset
    assert schedule.show_start_marker
    assert schedule.show_end_marker
  end

  test 'is not visible outside the chart range' do
    schedule = @builder.build(
      :start_on => @date_from - 10,
      :end_on => @date_from - 2,
      :progress => 0,
      :markers => false,
      :label => 'Outside'
    )

    assert_not schedule.visible?
  end

  test 'preserves the legacy gantt date calculations' do
    travel_to Date.new(2026, 1, 15) do
      gantt = Redmine::Helpers::Gantt.new(:year => 2026, :month => 1, :months => 1)
      builder = Redmine::Gantt::ScheduleBuilder.new(gantt)
      cases = [
        [Date.new(2025, 12, 28), Date.new(2026, 1, 1), 30],
        [Date.new(2026, 1, 1), Date.new(2026, 1, 1), 0],
        [Date.new(2026, 1, 8), Date.new(2026, 1, 22), 30],
        [Date.new(2026, 1, 31), Date.new(2026, 2, 2), 100],
        [Date.new(2026, 2, 2), Date.new(2026, 2, 4), 50]
      ]

      cases.each do |start_on, end_on, progress|
        legacy = gantt.send(:coordinates, start_on, end_on, progress, 1)
        schedule = builder.build(
          :start_on => start_on,
          :end_on => end_on,
          :progress => progress,
          :markers => true,
          :label => '_'
        )

        assert_offset legacy[:start], schedule.start_offset
        assert_offset legacy[:end], schedule.end_offset
        assert_offset legacy[:bar_start], schedule.bar_start_offset
        assert_offset legacy[:bar_end], schedule.bar_end_offset
        assert_offset legacy[:bar_progress_end], schedule.progress_offset
        assert_offset legacy[:bar_late_end], schedule.late_offset
      end
    end
  end

  private

  def assert_offset(expected, actual)
    expected.nil? ? assert_nil(actual) : assert_equal(expected, actual)
  end
end
