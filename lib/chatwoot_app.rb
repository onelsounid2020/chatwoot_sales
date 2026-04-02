# frozen_string_literal: true

require 'pathname'

module ChatwootApp
  TRUE_VALUES = %w[true 1 yes on].freeze

  def self.root
    Pathname.new(File.expand_path('..', __dir__))
  end

  def self.max_limit
    100_000
  end

  def self.lite_mode?
    env_flag_enabled?('LITE_MODE')
  end

  def self.enterprise?
    return false if enterprise_disabled?

    @enterprise ||= root.join('enterprise').exist?
  end

  def self.chatwoot_cloud?
    enterprise? && GlobalConfig.get_value('DEPLOYMENT_ENV') == 'cloud'
  end

  def self.self_hosted_enterprise?
    enterprise? && !chatwoot_cloud? && GlobalConfig.get_value('INSTALLATION_PRICING_PLAN') == 'enterprise'
  end

  def self.custom?
    @custom ||= root.join('custom').exist?
  end

  def self.help_center_root
    ENV.fetch('HELPCENTER_URL', nil) || ENV.fetch('FRONTEND_URL', nil)
  end

  def self.extensions
    if custom?
      enterprise? ? %w[enterprise custom] : %w[custom]
    elsif enterprise?
      %w[enterprise]
    else
      %w[]
    end
  end

  def self.advanced_search_allowed?
    enterprise? && ENV.fetch('OPENSEARCH_URL', nil).present?
  end

  def self.otel_enabled?
    otel_provider = InstallationConfig.find_by(name: 'OTEL_PROVIDER')&.value
    secret_key = InstallationConfig.find_by(name: 'LANGFUSE_SECRET_KEY')&.value

    otel_provider.present? && secret_key.present? && otel_provider == 'langfuse'
  end

  def self.enterprise_disabled?
    env_flag_enabled?('DISABLE_ENTERPRISE') || lite_mode?
  end

  def self.env_flag_enabled?(key)
    TRUE_VALUES.include?(ENV.fetch(key, '').to_s.strip.downcase)
  end
end
