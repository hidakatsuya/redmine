class CreateReactions < ActiveRecord::Migration[7.2]
  def change
    create_table :reactions do |t|
      t.references :reactable, polymorphic: true
      t.references :user, foreign_key: true
      t.timestamps null: false
    end
    add_index :reactions, [:reactable_type, :reactable_id, :user_id], unique: true
  end
end
