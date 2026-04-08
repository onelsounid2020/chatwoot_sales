# == Schema Information
#
# Table name: help_center_search_terms
#
#  id               :bigint           not null, primary key
#  category_slug    :string           default(""), not null
#  last_seen_at     :datetime         not null
#  locale           :string           not null
#  no_results_count :integer          default(0), not null
#  query            :string           not null
#  searches_count   :integer          default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  portal_id        :bigint           not null
#
# Indexes
#
#  index_hc_search_terms_on_portal_category_locale_query  (portal_id,category_slug,locale,query) UNIQUE
#
class HelpCenterSearchTerm < ApplicationRecord
  belongs_to :account
  belongs_to :portal

  validates :locale, :query, presence: true

  scope :for_portal, ->(portal) { where(portal_id: portal.id) }
  scope :for_locale, ->(locale) { where(locale: locale) if locale.present? }
  scope :for_category_slug, ->(category_slug) { where(category_slug: category_slug.to_s) if category_slug.present? }
  scope :top_unanswered, lambda { |portal:, locale:, category_slug:, limit: 5|
    for_portal(portal)
      .for_locale(locale)
      .for_category_slug(category_slug)
      .where('no_results_count > 0')
      .order(no_results_count: :desc, last_seen_at: :desc)
      .limit(limit)
  }

  def self.track!(portal:, locale:, category_slug:, query:, results_count:)
    normalized_query = query.to_s.strip.downcase
    return if normalized_query.blank?

    record = find_or_initialize_by(
      portal_id: portal.id,
      category_slug: category_slug.to_s,
      locale: locale.to_s,
      query: normalized_query
    )
    record.account_id ||= portal.account_id
    record.searches_count = record.searches_count.to_i + 1
    record.no_results_count = record.no_results_count.to_i + (results_count.to_i.zero? ? 1 : 0)
    record.last_seen_at = Time.current
    record.save!
  end
end
