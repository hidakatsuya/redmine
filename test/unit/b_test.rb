require_relative '../test_helper'

class BTest < ActiveSupport::TestCase
  fixtures :projects

  test "B test" do
    puts "-- B test"
    assert User.exists?(1)
  end
end
