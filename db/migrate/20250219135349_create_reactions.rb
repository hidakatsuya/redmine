class CreateReactions < ActiveRecord::Migration[7.2]
  def change
    create_table :reactions do |t|
      t.references :reactable, polymorphic: true, index: true
      t.references :user, foreign_key: true
      t.timestamps null: false
    end
  end
end
