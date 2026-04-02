class AddLostReasonToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :lost_reason, :string
    add_index :conversations, [:account_id, :lost_reason], name: 'index_conversations_on_account_id_and_lost_reason'
  end
end
