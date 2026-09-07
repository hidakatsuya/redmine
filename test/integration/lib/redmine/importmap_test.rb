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

require_relative '../../../test_helper'

class ImportmapTest < Redmine::IntegrationTest
  def setup
    @original_plugin_dir = Redmine::PluginLoader.directory

    Redmine::Plugin.clear
    Redmine::PluginLoader.directory = Rails.root.join('test/fixtures/plugins')
    Redmine::Plugin.directory = Rails.root.join('test/fixtures/plugins')
    Redmine::PluginLoader.load
    Redmine::PluginLoader.directories.each(&:run_initializer)
    Rails.application.reloader.prepare!
  end

  def teardown
    Redmine::Plugin.clear
    Redmine::PluginLoader.directory = @original_plugin_dir
    Redmine::Plugin.directory = @original_plugin_dir
    Redmine::PluginLoader.load
    Rails.application.reloader.prepare!
  end

  def test_plugin_stimulus_controllers_are_available_on_importmap
    get '/'

    assert_response :success
    assert_select 'script[type="importmap"]', text: /"controllers\/redmine_test_plugin_foo\/test_plugin_controller"/
    assert_select 'script[type="importmap"]', text: %r{/assets/plugin_assets/redmine_test_plugin_foo/javascripts/controllers/test_plugin_controller(?:-[^"]+)?\.js}
  end
end
