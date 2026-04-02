# frozen_string_literal: true

class AddSalesFieldsToContacts < ActiveRecord::Migration[7.0]
  def change
    add_column :contacts, :lead_stage, :integer, null: false, default: 0
    add_column :contacts, :deal_value, :decimal, precision: 12, scale: 2
    add_column :contacts, :next_follow_up_at, :datetime
    add_column :contacts, :last_contacted_at, :datetime

    add_index :contacts, [:account_id, :lead_stage], name: 'index_contacts_on_account_id_and_lead_stage'
    add_index :contacts, :next_follow_up_at
    add_index :contacts, :last_contacted_at
  end
end
