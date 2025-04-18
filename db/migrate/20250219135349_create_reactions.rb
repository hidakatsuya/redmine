class CreateReactions < ActiveRecord::Migration[7.2]
  def change
    create_table :reactions do |t|
      t.references :reactable, polymorphic: true, null: false
      t.references :user, foreign_key: true, null: false
      t.timestamps null: false
    end
    add_index :reactions, [:reactable_type, :reactable_id, :user_id], unique: true
  end
end
