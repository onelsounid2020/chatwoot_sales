class Api::V1::Accounts::ArticlesController < Api::V1::Accounts::BaseController
  before_action :portal
  before_action :check_authorization
  before_action :fetch_article, except: [:index, :create, :reorder]
  before_action :set_current_page, only: [:index]

  def index
    @portal_articles = @portal.articles

    set_article_count

    @articles = @articles.search(list_params)

    @articles = if list_params[:category_slug].present?
                  @articles.order_by_position.page(@current_page)
                else
                  @articles.order_by_updated_at.page(@current_page)
                end
  end

  def show; end
  def edit; end

  def create
    params_with_defaults = article_params
    params_with_defaults[:status] ||= :draft
    @article = @portal.articles.create!(params_with_defaults)
    @article.associate_root_article(article_params[:associated_article_id])
    render json: { error: @article.errors.messages }, status: :unprocessable_entity and return unless @article.valid?
  end

  def update
    @article.update!(article_params) if params[:article].present?
    render json: { error: @article.errors.messages }, status: :unprocessable_entity and return unless @article.valid?
  end

  def destroy
    @article.destroy!
    head :ok
  end

  def reorder
    Article.update_positions(portal: @portal, positions_hash: params[:positions_hash])
    head :ok
  end

  private

  def set_article_count
    # Search the params without status and author_id, use this to
    # compute mine count published draft etc
    base_search_params = list_params.except(:status, :author_id)
    @articles = @portal_articles.search(base_search_params)

    @articles_count = @articles.count
    @mine_articles_count = @articles.search_by_author(Current.user.id).count
    @published_articles_count = @articles.published.count
    @draft_articles_count = @articles.draft.count
    @archived_articles_count = @articles.archived.count
    @feedback_insights = low_feedback_articles(
      limit: 5,
      locale: list_params[:locale],
      category_slug: list_params[:category_slug]
    )
    @unanswered_searches = HelpCenterSearchTerm.top_unanswered(
      portal: @portal,
      locale: list_params[:locale],
      category_slug: list_params[:category_slug],
      limit: 5
    )
  end

  def low_feedback_articles(limit:, locale:, category_slug:)
    published_articles = @portal_articles.published
    published_articles = published_articles.where(locale: locale) if locale.present?
    published_articles = published_articles.search_by_category_slug(category_slug) if category_slug.present?
    published_articles = published_articles.order(updated_at: :desc).limit(200)

    published_articles.filter_map do |article|
      counts = article.feedback_counts
      yes_count = counts[:yes].to_i
      no_count = counts[:no].to_i
      total_votes = yes_count + no_count
      next if total_votes < 3

      {
        id: article.id,
        title: article.title,
        score: article.feedback_score,
        total_votes: total_votes,
        yes_count: yes_count,
        no_count: no_count
      }
    end.sort_by { |entry| [entry[:score], -entry[:total_votes]] }.first(limit)
  end

  def fetch_article
    @article = @portal.articles.find(params[:id])
  end

  def portal
    @portal ||= Current.account.portals.find_by!(slug: params[:portal_id])
  end

  def article_params
    params.require(:article).permit(
      :title, :slug, :position, :content, :description, :category_id, :author_id, :associated_article_id, :status,
      :locale, meta: [:title,
                      :description,
                      { tags: [] }]
    )
  end

  def list_params
    params.permit(:locale, :query, :page, :category_slug, :status, :author_id)
  end

  def set_current_page
    @current_page = params[:page] || 1
  end
end
