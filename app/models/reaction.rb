class Reaction < ApplicationRecord
  belongs_to :reactable, polymorphic: true
  belongs_to :user

  scope :by, ->(user) { where(user: user) }
end
