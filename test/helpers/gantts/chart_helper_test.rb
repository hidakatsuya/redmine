# frozen_string_literal: true

require_relative '../../test_helper'

class Gantts::ChartHelperTest < Redmine::HelperTest
  include Gantts::ChartHelper

  Segment = Struct.new(:layer, :label, :start_offset, :span, :kind, :non_working_day, keyword_init: true)

  test 'builds semantic scale classes and preserves scale style' do
    segment = Segment.new(:layer => 2, :label => 'Mon', :start_offset => 3, :span => 1,
                          :kind => :day_name, :non_working_day => true)

    assert_equal ['gantt__scale-segment', 'gantt__scale-segment--day-name', {'is-non-working-day': true}],
                 gantt_scale_segment_css_classes(segment)
    assert_equal '--gantt-segment-start: 3; --gantt-segment-span: 1; --gantt-scale-layer: 2',
                 gantt_scale_segment_style(segment)
  end

  test 'builds subject wrapper, semantic classes, row styles, and progress states' do
    row = stub(:depth => 2, :row_key => 'issue-1', :parent_row_key => 'project-1', :kind => :issue,
               :project? => false, :version? => false, :issue? => true,
               :expandable? => false, :context_menu? => true, :closed? => false,
               :overdue? => true, :behind_schedule? => false,
               :over_end_date? => false, :behind_start_date? => true)

    assert_equal '--gantt-depth: 2', gantt_row_style(row)
    assert_equal 'task-todo-issue-1', gantt_bar_dom_id(row, 'task-todo')
    assert_equal 'behind-start', gantt_progress_state(row)
    row_tag = gantt_row_tag(row) {'Row'}
    assert_include 'id="gantt-row-issue-1"', row_tag
    assert_include 'class="gantt__row gantt__row--issue"', row_tag
    assert_include 'data-gantt--chart-target="row"', row_tag
    assert_include 'data-gantt--subjects-target="row"', row_tag
    assert_include 'data-parent-row-key="project-1"', row_tag
    assert_include 'data-progress-state="behind-start"', row_tag
    subject = gantt_row_subject_tag(row) {'Subject'}
    assert_include 'id="issue-1"', subject
    assert_include 'gantt__subject--issue', subject
    assert_include 'hascontextmenu', subject
    assert_not_include 'is-open', subject
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
