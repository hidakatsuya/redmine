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
        # Wrap the <pre> element with a container and add a copy button
        node.wrap(wrapper)

        # Copy the contents of the pre tag when copyButton is clicked
        node.parent.prepend_child(button)
      end

      def wrapper
        @wrapper ||= Nokogiri::HTML5.fragment('<div class="pre-wrapper" data-controller="clipboard"></div>').children.first
      end

      def button
        icon = ApplicationController.helpers.sprite_icon('copy-pre-content', size: 18)
        button_copy = ApplicationController.helpers.l(:button_copy)
        escaped_button_copy = ERB::Util.html_escape(button_copy)
        html =
          '<a class="copy-pre-content-link icon-only" ' \
          'data-controller="tooltip" ' \
          'data-action="clipboard#copyPre mouseenter->tooltip#show mouseleave->tooltip#hide ' \
          'focusin->tooltip#show focusout->tooltip#hide keydown.esc->tooltip#hide" ' \
          "data-tooltip-text-value=\"#{escaped_button_copy}\">" +
          icon +
          '</a>'
        Nokogiri::HTML5.fragment(html).children.first
      end
    end
  end
end
