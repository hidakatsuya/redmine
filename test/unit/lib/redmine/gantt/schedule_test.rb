# frozen_string_literal: true

require_relative '../../../../test_helper'

class Redmine::Gantt::ScheduleTest < ActiveSupport::TestCase
  OFFSETS = {
    :start => :start_offset,
    :end => :end_offset,
    :bar_start => :bar_start_offset,
    :bar_end => :bar_end_offset,
    :bar_progress_end => :progress_offset,
    :bar_late_end => :late_offset
  }.freeze
  setup do
    @date_from = Date.new(2026, 1, 1)
    @gantt = stub(:date_from => @date_from, :date_to => Date.new(2026, 1, 31))
  end

  test 'clips schedules and markers at the visible range boundaries' do
    schedule = build(:start_on => @date_from - 2, :end_on => @date_from + 40, :progress => nil, :markers => true, :label => 'Clipped')

    assert_equal 0, schedule.bar_start_offset
    assert_equal 31, schedule.bar_end_offset
    assert_not schedule.start_marker?
    assert_not schedule.end_marker?
  end

  test 'uses day offsets and exposes progress and late portions' do
    travel_to Date.new(2026, 1, 15) do
      schedule = build(:start_on => @date_from + 4, :end_on => @date_from + 20, :progress => 40, :markers => true, :label => 'Schedule')

      assert_equal 4, schedule.bar_start_offset
      assert_equal 21, schedule.bar_end_offset
      assert_in_delta 10.8, schedule.progress_offset
      assert_equal 15, schedule.late_offset
      assert schedule.progress?
      assert schedule.late?
      assert schedule.start_marker?
      assert schedule.end_marker?
      assert_predicate schedule, :frozen?
    end
  end

  test 'is not visible outside the chart range' do
    schedule = build(:start_on => @date_from - 10, :end_on => @date_from - 2, :progress => 0, :markers => false, :label => 'Outside')

    assert_not schedule.visible?
    assert_not schedule.progress?
    assert_not schedule.late?
  end

  test 'retains fractional progress until converted to output units' do
    schedule = build(:start_on => Date.new(2026, 1, 8), :end_on => Date.new(2026, 1, 22),
                     :progress => 30, :markers => true, :label => '_')

    assert_equal 11.5, schedule.progress_offset
    assert_equal [23, 46, 92, 184], [2, 4, 8, 16].map {|width| (schedule.progress_offset * width).floor}
  end

  test 'shares unrounded date offsets with exports' do
    offsets = Redmine::Gantt::Schedule.offsets(:date_from => @date_from, :date_to => Date.new(2026, 1, 31),
                                              :start_on => Date.new(2026, 1, 8), :end_on => Date.new(2026, 1, 22),
                                              :progress => 30, :today => Date.new(2026, 1, 15))

    assert_equal({:start => 7, :end => 22, :bar_start => 7, :bar_end => 22,
                  :bar_progress_end => 11.5, :bar_late_end => 15}, offsets)
  end

  private

  def build(**attributes)
    Redmine::Gantt::Schedule.build(gantt: @gantt, **attributes)
  end
end
