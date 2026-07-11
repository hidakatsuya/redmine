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
end
