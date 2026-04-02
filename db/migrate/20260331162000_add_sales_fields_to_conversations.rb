# frozen_string_literal: true

class AddSalesFieldsToConversations < ActiveRecord::Migration[7.0]
  def up
    add_column :conversations, :deal_stage, :integer, null: false, default: 0
    add_column :conversations, :deal_value, :decimal, precision: 12, scale: 2
    add_column :conversations, :next_follow_up_at, :datetime
    add_column :conversations, :last_contacted_at, :datetime

    add_index :conversations, [:account_id, :deal_stage], name: 'index_conversations_on_account_id_and_deal_stage'
    add_index :conversations, :next_follow_up_at
    add_index :conversations, :last_contacted_at

    execute <<~SQL.squish
      UPDATE conversations
      SET
        deal_stage = contacts.lead_stage,
        deal_value = contacts.deal_value,
        next_follow_up_at = contacts.next_follow_up_at,
        last_contacted_at = contacts.last_contacted_at
      FROM contacts
      WHERE conversations.contact_id = contacts.id
    SQL
  end

  def down
    remove_index :conversations, name: 'index_conversations_on_account_id_and_deal_stage'
    remove_index :conversations, :next_follow_up_at
    remove_index :conversations, :last_contacted_at

    remove_column :conversations, :deal_stage
    remove_column :conversations, :deal_value
    remove_column :conversations, :next_follow_up_at
    remove_column :conversations, :last_contacted_at
  end
end
