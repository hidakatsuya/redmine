# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
# This code is released under the GNU General Public License.

module Redmine
  module WikiFormatting
    class CopypreScrubber < Loofah::Scrubber
      def scrub(node)
        return unless node.name == 'pre'

        node['data-clipboard-target'] = 'pre'
        # Create the wrapper in the current document so a shared node does not retain processed documents.
        node.wrap('<div class="pre-wrapper" data-controller="clipboard"></div>')

        # Copy the contents of the pre tag when copyButton is clicked
        node.parent.prepend_child(button)
      end

      def button
        icon = ApplicationController.helpers.sprite_icon('copy-pre-content', size: 18)
        button_copy = ApplicationController.helpers.l(:button_copy)
        html = '<a class="copy-pre-content-link icon-only" title="' + button_copy + '" data-action="clipboard#copyPre">' + icon + '</a>'
        Nokogiri::HTML5.fragment(html).children.first
      end
    end
  end
end
