class Api::V1::Accounts::PortalsController < Api::V1::Accounts::BaseController
  include ::FileTypeHelper

  before_action :fetch_portal, except: [:index, :create]
  before_action :check_authorization
  before_action :set_current_page, only: [:index]

  def index
    @portals = Current.account.portals
  end

  def show
    @all_articles = @portal.articles
    @articles = @all_articles.search(locale: params[:locale])
  end

  def create
    @portal = Current.account.portals.build(merged_portal_params)
    @portal.custom_domain = parsed_custom_domain
    @portal.save!
    process_attached_logo
  end

  def update
    ActiveRecord::Base.transaction do
      @portal.update!(merged_portal_params) if params[:portal].present?
      # @portal.custom_domain = parsed_custom_domain
      process_attached_logo if params[:blob_id].present?
    rescue ActiveRecord::RecordInvalid => e
      render_record_invalid(e)
    end
  end

  def destroy
    @portal.destroy!
    head :ok
  end

  def archive
    @portal.update(archive: true)
    head :ok
  end

  def logo
    @portal.logo.purge if @portal.logo.attached?
    head :ok
  end

  def send_instructions
    email = permitted_params[:email]
    return render_could_not_create_error(I18n.t('portals.send_instructions.email_required')) if email.blank?
    return render_could_not_create_error(I18n.t('portals.send_instructions.invalid_email_format')) unless valid_email?(email)
    return render_could_not_create_error(I18n.t('portals.send_instructions.custom_domain_not_configured')) if @portal.custom_domain.blank?

    PortalInstructionsMailer.send_cname_instructions(
      portal: @portal,
      recipient_email: email
    ).deliver_later

    render json: { message: I18n.t('portals.send_instructions.instructions_sent_successfully') }, status: :ok
  end

  def process_attached_logo
    blob_id = params[:blob_id]
    blob = ActiveStorage::Blob.find_signed(blob_id)
    @portal.logo.attach(blob)
  end

  private

  def fetch_portal
    @portal = Current.account.portals.find_by(slug: permitted_params[:id])
  end

  def permitted_params
    params.permit(:id, :email)
  end

  def portal_params
    params.require(:portal).permit(
      :id, :color, :custom_domain, :header_text, :homepage_link,
      :name, :page_title, :slug, :archived, { config: [:default_locale, { allowed_locales: [] }, { draft_locales: [] }] }
    )
  end

  def portal_theme_params
    params.require(:portal).permit(
      :header_bg_color, :header_text_color, :home_bg_color, :article_bg_color, :article_text_color,
      :hero_bg_color, :hero_title_color, :hero_subtitle_color,
      :card_bg_color, :card_border_color, :card_title_color, :card_text_color,
      :visual_template, :home_layout_mode, :typography_preset, :content_width,
      :density_mode, :card_style, :text_align, :header_style, :advanced_section_spacing,
      :advanced_card_radius, :advanced_shadow_style, :hero_style,
      :category_columns, :article_link_style
    ).to_h.compact
  end

  def merged_portal_params
    merged_params = portal_params.merge(live_chat_widget_params)
    return merged_params if portal_theme_params.empty?

    existing_config = @portal&.config || {}
    merged_params[:config] = existing_config.merge(merged_params[:config] || {}).merge(portal_theme_params)
    merged_params
  end

  def live_chat_widget_params
    permitted_params = params.permit(:inbox_id)
    return {} unless permitted_params.key?(:inbox_id)
    return { channel_web_widget_id: nil } if permitted_params[:inbox_id].blank?

    inbox = Inbox.find(permitted_params[:inbox_id])
    return {} unless inbox.web_widget?

    { channel_web_widget_id: inbox.channel.id }
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def parsed_custom_domain
    domain = URI.parse(@portal.custom_domain)
    domain.is_a?(URI::HTTP) ? domain.host : @portal.custom_domain
  end

  def valid_email?(email)
    ValidEmail2::Address.new(email).valid?
  end
end

Api::V1::Accounts::PortalsController.prepend_mod_with('Api::V1::Accounts::PortalsController')
