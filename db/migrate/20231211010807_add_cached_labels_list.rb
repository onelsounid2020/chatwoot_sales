class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def up
    add_column :conversations, :cached_label_list, :string
  end

  def down
    remove_column :conversations, :cached_label_list
  end
end