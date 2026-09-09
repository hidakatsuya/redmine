# frozen_string_literal: true

require_relative '../../test_helper'

class Gantts::ChartHelperTest < Redmine::HelperTest
  include Gantts::ChartHelper

  Segment = Struct.new(:layer, :label, :start_offset, :span, :kind, :non_working_day, :title, keyword_init: true)

  test 'wraps view-provided scale content with calendar classes and position' do
    segment = Segment.new(layer: 2, label: 'Mon', start_offset: 3, span: 1,
                          kind: :day_name, non_working_day: true)

    html = gantt_scale_segment_tag(segment) { tag.span 'Mon', class: 'weekday' }
    cell = Nokogiri::HTML.fragment(html).at_css('div.gantt__scale-segment--day-name.is-non-working-day')
    assert cell
    assert_equal 'Mon', cell.at_css('span.weekday').text
    assert_equal gantt_scale_segment_style(segment), cell['style']
    assert_equal '--gantt-segment-start: 3; --gantt-segment-span: 1; --gantt-scale-layer: 2',
                 gantt_scale_segment_style(segment)
  end

  test 'builds subject wrapper, semantic classes, row styles, and progress states' do
    row = stub(depth: 2, row_key: 'issue-1', parent_row_key: 'project-1', kind: :issue,
               project?: false, version?: false, issue?: true,
               expandable?: false, context_menu?: true, closed?: false,
               overdue?: true, behind_schedule?: false,
               over_end_date?: false, behind_start_date?: true)

    assert_equal '--gantt-depth: 2', gantt_row_style(row)
    assert_equal 'behind-start', gantt_row_progress_state(row)
    row_tag = tag.div(**gantt_row_attributes(row)) {'Row'}
    assert_include 'id="gantt-row-issue-1"', row_tag
    assert_include 'class="gantt__row gantt__row--issue"', row_tag
    assert_include 'data-gantt--chart-target="row"', row_tag
    assert_include 'data-gantt--subjects-target="row"', row_tag
    assert_include 'data-parent-row-key="project-1"', row_tag
    assert_include 'data-progress-state="behind-start"', row_tag
    subject = tag.div(**gantt_row_subject_attributes(row)) {'Subject'}
    assert_include 'id="issue-1"', subject
    assert_include 'gantt__subject--issue', subject
    assert_include 'hascontextmenu', subject
    assert_not_include 'is-open', subject
  end

  test 'renders only schedule endpoints within the displayed period' do
    gantt = stub(date_from: Date.new(2026, 6, 1), date_to: Date.new(2026, 6, 30))
    [
      [Date.new(2026, 6, 1), Date.new(2026, 6, 30), { start: 0.0, end: 30.0 }],
      [Date.new(2026, 5, 31), Date.new(2026, 6, 30), { end: 30.0 }],
      [Date.new(2026, 6, 1), Date.new(2026, 7, 1), { start: 0.0 }],
      [Date.new(2026, 5, 31), Date.new(2026, 7, 1), {}]
    ].each do |start_on, end_on, endpoints|
      schedule = Redmine::Gantt::Schedule.build(gantt: gantt, start_on: start_on, end_on: end_on,
                                               progress: nil, markers: true, label: 'Project')
      row = stub(schedule: schedule, issue?: false, kind: :project)

      [:start, :end].each do |side|
        html = gantt_schedule_marker_tag(row, side)
        if endpoints.key?(side)
          marker = Nokogiri::HTML.fragment(html).at_css("div.task.project.gantt__marker--#{side}")
          assert marker
          assert_equal "--gantt-marker-unit: #{endpoints[side]}", marker['style']
        else
          assert_nil html
        end
      end
    end
  end

  test 'builds chart styles including selected column dimensions' do
    chart = stub(selected_columns: [stub, stub], row_height: 20, row_count: 3, header_layers: 2, day_width: 4,
                 sidebar_subject_width: 330, timeline_width: 120, relations: [], show_selected_columns?: true,
                 show_relations?: false, show_progress_line?: true)

    html = gantt_chart_tag(chart, project: stub(id: 7)) { tag.span 'chart content', class: 'content' }
    root = Nokogiri::HTML.fragment(html).at_css('div.gantt')
    assert_equal 'chart content', root.at_css('span.content').text
    assert_equal '7', root['data-gantt-project-id']
    styles = JSON.parse(root['data-gantt--chart-issue-relation-types-value'])
    assert_equal Redmine::Gantt::Dataset::RELATION_TYPES.sort, styles.keys.sort
    assert_equal({ 'landscape_margin' => 16, 'color' => '#fa5252' }, styles.fetch(IssueRelation::TYPE_BLOCKS))
    assert_equal({ 'landscape_margin' => 20, 'color' => '#228be6' }, styles.fetch(IssueRelation::TYPE_PRECEDES))

    assert_include 'is-showing-columns', html
    assert_include '--gantt-selected-columns-width: 100px', html
    assert_include 'data-gantt--chart-column-widths-value="[50,50]"', html
  end
end
