module Redmine
  module Gantt
    class ScaleSegment
      attr_reader :layer, :label, :start_offset, :span, :css_classes, :title

      def initialize(layer:, label:, start_offset:, span:, css_classes:, title: nil)
        @layer = layer
        @label = label
        @start_offset = start_offset
        @span = span
        @css_classes = css_classes
        @title = title
      end
    end
  end
end
