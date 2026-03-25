class AddIsTemplateToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :is_template, :boolean, :null => false, :default => false
    add_index :projects, :is_template
  end
end
