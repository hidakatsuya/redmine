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
      assert_equal 10, schedule.progress_offset
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

  test 'preserves the legacy gantt date calculations' do
    travel_to Date.new(2026, 1, 15) do
      gantt = Redmine::Helpers::Gantt.new(:year => 2026, :month => 1, :months => 1)
      [[Date.new(2025, 12, 28), Date.new(2026, 1, 1), 30], [Date.new(2026, 1, 1), Date.new(2026, 1, 1), 0],
       [Date.new(2026, 1, 8), Date.new(2026, 1, 22), 30], [Date.new(2026, 1, 31), Date.new(2026, 2, 2), 100],
       [Date.new(2026, 2, 2), Date.new(2026, 2, 4), 50]].each do |start_on, end_on, progress|
        legacy = gantt.send(:coordinates, start_on, end_on, progress, 1)
        schedule = Redmine::Gantt::Schedule.build(:gantt => gantt, :start_on => start_on, :end_on => end_on,
                                                   :progress => progress, :markers => true, :label => '_')
        OFFSETS.each do |key, reader|
          actual = schedule.public_send(reader)
          legacy[key] ? assert_equal(legacy[key], actual) : assert_nil(actual)
        end
      end
    end
  end

  private

  def build(**attributes)
    Redmine::Gantt::Schedule.build(gantt: @gantt, **attributes)
  end
end
