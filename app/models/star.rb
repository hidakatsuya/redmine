class Star < ApplicationRecord
  belongs_to :starable, polymorphic: true
  belongs_to :user

  scope :by, ->(user) { where(user: user) }
end
