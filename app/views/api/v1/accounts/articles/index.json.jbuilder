json.payload do
  json.array! @articles, partial: 'article', as: :article
end

json.meta do
  json.all_articles_count @portal_articles.size
  json.archived_articles_count @archived_articles_count
  json.articles_count @articles_count
  json.current_page @current_page
  json.draft_articles_count @draft_articles_count
  json.mine_articles_count @mine_articles_count
  json.published_count @published_articles_count
  json.feedback_insights @feedback_insights
  json.insights_scope do
    json.locale params[:locale]
    json.category_slug params[:category_slug]
  end
  json.unanswered_searches do
    json.array! @unanswered_searches do |search_term|
      json.query search_term.query
      json.no_results_count search_term.no_results_count
      json.searches_count search_term.searches_count
      json.last_seen_at search_term.last_seen_at.to_i
    end
  end
end
