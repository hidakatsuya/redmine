class CreateStars < ActiveRecord::Migration[7.2]
  def change
    create_table :stars do |t|
      t.references :starable, polymorphic: true, index: true
      t.references :user, foreign_key: true
      t.timestamps null: false
    end
  end
end
