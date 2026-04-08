json.id portal.id
json.color portal.color
json.custom_domain portal.custom_domain
json.header_text portal.header_text
json.homepage_link portal.homepage_link
json.name portal.name
json.page_title portal.page_title
json.slug portal.slug
json.archived portal.archived
json.account_id portal.account_id
json.header_bg_color portal.config&.dig('header_bg_color')
json.header_text_color portal.config&.dig('header_text_color')
json.home_bg_color portal.config&.dig('home_bg_color')
json.article_bg_color portal.config&.dig('article_bg_color')
json.article_text_color portal.config&.dig('article_text_color')
json.article_title_color portal.config&.dig('article_title_color')
json.hero_bg_color portal.config&.dig('hero_bg_color')
json.hero_title_color portal.config&.dig('hero_title_color')
json.hero_subtitle_color portal.config&.dig('hero_subtitle_color')
json.card_bg_color portal.config&.dig('card_bg_color')
json.card_border_color portal.config&.dig('card_border_color')
json.card_title_color portal.config&.dig('card_title_color')
json.card_text_color portal.config&.dig('card_text_color')
json.typography_preset portal.config&.dig('typography_preset')
json.content_width portal.config&.dig('content_width')
json.density_mode portal.config&.dig('density_mode')
json.card_style portal.config&.dig('card_style')
json.text_align portal.config&.dig('text_align')
json.header_style portal.config&.dig('header_style')
json.visual_template portal.config&.dig('visual_template')
json.home_layout_mode portal.config&.dig('home_layout_mode')
json.advanced_section_spacing portal.config&.dig('advanced_section_spacing')
json.advanced_card_radius portal.config&.dig('advanced_card_radius')
json.advanced_shadow_style portal.config&.dig('advanced_shadow_style')
json.hero_style portal.config&.dig('hero_style')
json.category_columns portal.config&.dig('category_columns')
json.article_link_style portal.config&.dig('article_link_style')
json.article_title_align portal.config&.dig('article_title_align')

json.config do
  json.allowed_locales do
    json.array! portal.allowed_locale_codes.each do |locale|
      json.partial! 'api/v1/models/portal_config', formats: [:json], locale: locale, portal: portal
    end
  end
end

if portal.channel_web_widget
  json.inbox do
    json.partial! 'api/v1/models/inbox', formats: [:json], resource: portal.channel_web_widget.inbox
  end
end

json.logo portal.file_base_data if portal.logo.present?

json.meta do
  json.all_articles_count articles.try(:size)
  json.archived_articles_count articles.try(:archived).try(:size)
  json.published_count articles.try(:published).try(:size)
  json.draft_articles_count articles.try(:draft).try(:size)
  json.mine_articles_count articles.search_by_author(current_user.id).try(:size) if current_user.present? && articles.any?
  json.categories_count portal.categories.try(:size)
  json.default_locale portal.default_locale
end

if portal.ssl_settings.present?
  json.ssl_settings do
    json.status portal.ssl_settings['cf_status']
    json.verification_errors portal.ssl_settings['cf_verification_errors']
  end
end
