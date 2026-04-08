class Public::Api::V1::Portals::ArticlesController < Public::Api::V1::Portals::BaseController
  before_action :ensure_custom_domain_request, only: [:show, :index]
  before_action :portal
  before_action :ensure_portal_feature_enabled
  before_action :set_category, except: [:index, :show, :tracking_pixel]
  before_action :set_article, only: [:show, :feedback]
  layout 'portal'

  def index
    @search_query = list_params[:query]
    @articles = @portal.articles.published.includes(:category, :author)

    @articles = @articles.where(locale: permitted_params[:locale]) if permitted_params[:locale].present?

    @articles_count = @articles.count

    search_articles
    @articles_count = @articles.count if @search_query.present?
    track_search_query
    order_by_sort_param
    limit_results
  end

  def show
    @og_image_url = helpers.set_og_image_url(@portal.name, @article.title)
    @section_articles = section_articles.limit(10)
    @section_articles_count = section_articles.count
    @related_articles = related_articles.limit(6)
    @most_viewed_articles = most_viewed_articles.limit(6)
    @feedback_counts = @article.feedback_counts
    @feedback_submitted = feedback_submitted?
  end

  def feedback
    vote = params[:vote].to_s
    feedback_reason = params[:feedback_reason].to_s
    return redirect_to(article_page_url) unless %w[yes no].include?(vote)

    unless feedback_submitted?
      @article.increment_feedback_count(vote)
      @article.increment_feedback_reason(feedback_reason) if vote == 'no'
      cookies[feedback_cookie_key] = {
        value: vote,
        expires: 1.year.from_now,
        httponly: true
      }
      flash[:notice] = I18n.t('public_portal.article_feedback.thanks')
    end

    redirect_to article_page_url
  end

  def tracking_pixel
    @article = @portal.articles.find_by(slug: permitted_params[:article_slug])
    return head :not_found unless @article

    @article.increment_view_count if @article.published?

    # Serve the 1x1 tracking pixel with 24-hour private cache
    # Private cache bypasses CDN but allows browser caching to prevent duplicate views from same user
    expires_in 24.hours, public: false
    response.headers['Content-Type'] = 'image/png'

    pixel_path = Rails.public_path.join('assets/images/tracking-pixel.png')
    send_file pixel_path, type: 'image/png', disposition: 'inline'
  end

  private

  def limit_results
    return if list_params[:per_page].blank?

    per_page = [list_params[:per_page].to_i, 100].min
    per_page = 25 if per_page < 1
    @articles = @articles.page(list_params[:page]).per(per_page)
  end

  def search_articles
    @articles = @articles.search(list_params) if list_params.present?
  end

  def order_by_sort_param
    @articles = if list_params[:sort].present? && list_params[:sort] == 'views'
                  @articles.order_by_views
                elsif @search_query.present?
                  @articles
                else
                  @articles.order_by_position
                end
  end

  def track_search_query
    return if @search_query.blank?

    HelpCenterSearchTerm.track!(
      portal: @portal,
      locale: permitted_params[:locale] || @portal.default_locale,
      category_slug: list_params[:category_slug],
      query: @search_query,
      results_count: @articles.size
    )
  end

  def set_article
    @article = @portal.articles.find_by(slug: permitted_params[:article_slug])
    @parsed_content = render_article_content(@article.content)
  end

  def set_category
    return if permitted_params[:category_slug].blank?

    @category = @portal.categories.find_by!(
      slug: permitted_params[:category_slug],
      locale: permitted_params[:locale]
    )
  end

  def list_params
    @list_params ||= params.permit(:query, :locale, :sort, :status, :page, :per_page).tap do |permitted|
      permitted[:query] = permitted[:query].to_s.strip.presence
    end
  end

  def permitted_params
    params.permit(:slug, :category_slug, :locale, :id, :article_slug)
  end

  def render_article_content(content)
    ChatwootMarkdownRenderer.new(content).render_article
  end

  def section_articles
    if @article.category_id.present?
      @article.category.articles.published.where(locale: @article.locale).order_by_position
    else
      @portal.articles.published.where(category_id: nil, locale: @article.locale).order_by_position
    end
  end

  def related_articles
    category_scope = if @article.category_id.present?
                       @portal.articles.published.where(category_id: @article.category_id, locale: @article.locale)
                     else
                       @portal.articles.published.where(category_id: nil, locale: @article.locale)
                     end

    related = category_scope.where.not(id: @article.id).order_by_views
    return related if related.any?

    @portal.articles.published.where(locale: @article.locale).where.not(id: @article.id).order_by_views
  end

  def most_viewed_articles
    @portal.articles.published.where(locale: @article.locale).where.not(id: @article.id).order_by_views
  end

  def article_page_url
    helpers.generate_article_link(@portal.slug, @article.slug, @theme_from_params, @is_plain_layout_enabled)
  end

  def feedback_cookie_key
    "hc_article_feedback_#{@article.id}"
  end

  def feedback_submitted?
    cookies[feedback_cookie_key].present?
  end
end

Public::Api::V1::Portals::ArticlesController.prepend_mod_with('Public::Api::V1::Portals::ArticlesController')
