json.custom_domain portal.custom_domain
json.header_text portal.header_text
json.homepage_link portal.homepage_link
json.name portal.name
json.page_title portal.page_title
json.slug portal.slug
json.home_bg_color portal.config&.dig('home_bg_color')
json.article_bg_color portal.config&.dig('article_bg_color')
json.article_text_color portal.config&.dig('article_text_color')
json.article_title_color portal.config&.dig('article_title_color')
json.article_title_align portal.config&.dig('article_title_align')

json.categories do
  if portal.categories.any?
    json.array! portal.categories.each do |category|
      json.partial! 'public/api/v1/models/category', formats: [:json], category: category
    end
  end
end

json.logo portal.file_base_data if portal.logo.present?

json.meta do
  json.articles_count portal.articles.published.size
  json.categories_count portal.categories.size
  json.default_locale portal.default_locale
end
