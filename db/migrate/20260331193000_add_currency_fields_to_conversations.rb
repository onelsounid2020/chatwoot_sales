class AddCurrencyFieldsToConversations < ActiveRecord::Migration[7.0]
  def up
    add_column :conversations, :deal_currency, :string, null: false, default: 'CLP'
    add_column :conversations, :deal_value_clp, :decimal, precision: 12, scale: 2
    add_column :conversations, :fx_rate_usd_clp, :decimal, precision: 12, scale: 4

    execute <<~SQL.squish
      UPDATE conversations
      SET deal_currency = 'CLP'
      WHERE deal_currency IS NULL OR deal_currency = ''
    SQL

    execute <<~SQL.squish
      UPDATE conversations
      SET deal_value_clp = deal_value,
          fx_rate_usd_clp = 1
      WHERE deal_value IS NOT NULL
    SQL
  end

  def down
    remove_column :conversations, :fx_rate_usd_clp
    remove_column :conversations, :deal_value_clp
    remove_column :conversations, :deal_currency
  end
end
