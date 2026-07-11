# frozen_string_literal: true

module Redmine
  module Gantt
    class Relation
      attr_reader :from_row_key, :to_row_key, :type

      def initialize(from_row_key:, to_row_key:, type:)
        @from_row_key = from_row_key
        @to_row_key = to_row_key
        @type = type
      end

      def to_h
        {
          :from_row_key => from_row_key,
          :to_row_key => to_row_key,
          :type => type
        }
      end
    end
  end
end
