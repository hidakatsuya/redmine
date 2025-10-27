# frozen_string_literal: true

require 'fileutils'
require_relative '../application_system_test_case'

module Vrt
  class ApplicationVrtTestCase < ApplicationSystemTestCase
    def self.output_dir
      Rails.root.join('test', 'vrt', ENV['VRT_OUTPUT'] || 'actual')
    end

    def capture_screenshot(test_name)
      filename = "#{test_name.parameterize(separator: '_')}.png"

      sleep 1
      page.save_screenshot self.class.output_dir.join(filename).to_s # rubocop:disable Lint/Debugger
    end
  end
end
