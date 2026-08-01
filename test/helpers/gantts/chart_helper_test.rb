# frozen_string_literal: true

require_relative '../../test_helper'

class Gantts::ChartHelperTest < Redmine::HelperTest
  include Gantts::ChartHelper
  include QueriesHelper

  Segment = Struct.new(:layer, :label, :start_on, :start_offset, :span, :kind, :non_working_day, :title, keyword_init: true)

  test 'builds semantic scale classes and preserves scale style' do
    segment = Segment.new(:layer => 2, :label => 'Mon', :start_offset => 3, :span => 1,
                          :kind => :day_name, :non_working_day => true)

    assert_equal ['gantt__scale-segment', 'gantt__scale-segment--day-name', 'is-non-working-day'],
                 gantt_scale_segment_css_classes(segment)
    assert_equal '--gantt-segment-start: 3; --gantt-segment-span: 1; --gantt-scale-layer: 2',
                 gantt_scale_segment_style(segment)
  end

  test 'builds scale links and labels from semantic segments' do
    gantt = stub(:params => {:controller => 'gantts', :action => 'show', :zoom => 2})
    month = Segment.new(:layer => 0, :label => '2026-2', :start_on => Date.new(2026, 2, 1),
                        :start_offset => 31, :span => 28,
                        :kind => :month, :non_working_day => false, :title => 'February 2026')
    week = Segment.new(:layer => 1, :label => '6', :start_offset => 35, :span => 7,
                       :kind => :week, :non_working_day => false)

    assert_include 'year=2026', gantt_scale_segment_content(month, gantt)
    assert_include 'month=2', gantt_scale_segment_content(month, gantt)
    assert_equal '<span>6</span>', gantt_scale_segment_content(week, gantt)
  end

  test 'builds subject DOM identifiers, row styles, and progress states' do
    record = issues(:issues_001)
    row = stub(:depth => 2, :row_key => 'issue-1', :project? => false, :closed? => false,
               :over_end_date? => false, :behind_start_date? => true)

    assert_equal '--gantt-depth: 2', gantt_row_style(row)
    assert_equal 'task-todo-issue-1', gantt_bar_dom_id(row, 'task-todo')
    assert_equal 'behind-start', gantt_progress_state(row)
    assert_include 'id="issue-1"', gantt_row_subject_tag(stub(:expandable? => false, :row_key => 'issue-1',
                                                            :subject => 'Subject'),
                                                           'Subject', [], [])
  end

  test 'renders issue selected column content and keeps other row kinds empty' do
    column = QueryColumn.new(:subject)
    issue = issues(:issues_001)

    assert_equal '', gantt_row_column_content(stub(:issue? => false), column)
    assert_include 'gantt__cell-value subject', gantt_row_column_content(stub(:issue? => true, :issue => issue), column)
  end

  test 'builds chart styles including selected column dimensions' do
    chart = stub(:selected_columns => [stub, stub], :row_height => 32, :header_layers => 2, :day_width => 4,
                 :sidebar_subject_width => 330, :timeline_width => 120, :relations => [], :show_selected_columns? => true,
                 :show_relations? => false, :show_progress_line? => true)

    html = gantt_chart_tag(chart) { 'chart' }

    assert_include 'is-showing-columns', html
    assert_include '--gantt-selected-columns-width: 192px', html
    assert_include 'data-gantt--chart-column-widths-value="[96,96]"', html
  end
end
