# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../application_system_test_case'

Capybara::Server::Middleware.prepend(Module.new do
  def call(env)
    if env['REQUEST_URI'].match?(%r{(/issues/auto_complete|/my/page|/login)})
      puts "request: #{env['REQUEST_METHOD']} #{env['REQUEST_URI']} (HTTP_COOKIE=#{env['HTTP_COOKIE']&.slice(0, 25)}...)"
      puts "pending_requests = (#{pending_requests.length}) #{pending_requests}"
    end
    super
  end
end)

Capybara::Session.prepend(Module.new do
  def reset!
    puts "Capybara::Session#reset! called"
    super
  end
end)

Capybara::Server.prepend(Module.new do
  def wait_for_pending_requests
    puts "Capybara::Server#wait_for_pending_requests called"
    super
  end
end)

class InlineAutocompleteSystemTest < ApplicationSystemTestCase
  def self.test_order = :sorted

  setup do
    page.server.send(:middleware).then do |m|
      puts "pending_requests? = #{m.pending_requests?}"
    end
  end

  teardown do
    page.server.send(:middleware).then do |m|
      puts "pending_requests? = #{m.pending_requests?}"
    end
  end

  def test_1
    Issue.generate!(subject: 'abcdefghijkl', project_id: 1, tracker_id: 1)

    log_user('jsmith', 'jsmith')
    visit 'projects/1/issues/new'

    fill_in 'Description', :with => '#abcdefghijkl'

    within('.tribute-container') do
      assert page.has_text? "abcdefghijkl"
    end
  end

  def test_2
    Capybara.reset_sessions!
    log_user('jsmith', 'jsmith')
  end
end
