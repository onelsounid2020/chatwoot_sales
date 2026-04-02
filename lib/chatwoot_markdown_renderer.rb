class ChatwootMarkdownRenderer
  ALLOWED_ARTICLE_TAGS = %w[
    a p br strong b em i u s del blockquote code pre
    h1 h2 h3 h4 h5 h6
    ul ol li
    table thead tbody tr th td
    hr
    img
  ].freeze
  ALLOWED_ARTICLE_ATTRIBUTES = %w[
    href target rel title
    src alt width height
    colspan rowspan
  ].freeze

  def initialize(content)
    @content = content
  end

  def render_message
    markdown_renderer = BaseMarkdownRenderer.new
    doc = CommonMarker.render_doc(@content, :DEFAULT, [:strikethrough, :autolink])
    html = markdown_renderer.render(doc)
    render_as_html_safe(html)
  end

  def render_article
    return render_as_html_safe(sanitized_article_html) if html_content?

    markdown_renderer = CustomMarkdownRenderer.new
    doc = CommonMarker.render_doc(@content, :DEFAULT, [:table])
    html = markdown_renderer.render(doc)

    render_as_html_safe(html)
  end

  def render_markdown_to_plain_text
    return ActionView::Base.full_sanitizer.sanitize(@content) if html_content?

    CommonMarker.render_doc(@content, :DEFAULT).to_plaintext
  end

  private

  def html_content?
    @content.to_s.match?(%r{</?[a-z][\s\S]*>}i)
  end

  def sanitized_article_html
    Rails::HTML5::SafeListSanitizer.new.sanitize(
      @content.to_s,
      tags: ALLOWED_ARTICLE_TAGS,
      attributes: ALLOWED_ARTICLE_ATTRIBUTES
    )
  end

  def render_as_html_safe(html)
    # rubocop:disable Rails/OutputSafety
    html.html_safe
    # rubocop:enable Rails/OutputSafety
  end
end
