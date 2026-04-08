class CreateHelpCenterSearchTerms < ActiveRecord::Migration[7.0]
  def change
    create_table :help_center_search_terms do |t|
      t.references :account, null: false, foreign_key: true
      t.references :portal, null: false, foreign_key: true
      t.string :category_slug, null: false, default: ''
      t.string :locale, null: false
      t.string :query, null: false
      t.integer :searches_count, null: false, default: 0
      t.integer :no_results_count, null: false, default: 0
      t.datetime :last_seen_at, null: false

      t.timestamps
    end

    add_index :help_center_search_terms, [:portal_id, :category_slug, :locale, :query], unique: true, name: 'index_hc_search_terms_on_portal_category_locale_query'
  end
end
