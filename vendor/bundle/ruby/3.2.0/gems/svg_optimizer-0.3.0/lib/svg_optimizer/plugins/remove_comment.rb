# frozen_string_literal: true

module SvgOptimizer
  module Plugins
    class RemoveComment < Base
      def process
        xml.xpath("//comment()").remove
      end
    end
  end
end
