require_relative '../test_helper'

class ATest < ActiveSupport::TestCase
  fixtures :users

  test "A test" do
    puts "-- A test"
    assert User.exists?(1)
  end
end
