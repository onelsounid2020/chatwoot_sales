class Conversations::ResolvePolicyService
  DEFAULT_RULES = {
    'allowed_deal_stages' => [],
    'required_conversation_custom_attributes' => [],
    'required_contact_custom_attributes' => []
  }.freeze

  def initialize(conversation)
    @conversation = conversation
    @account = conversation.account
    @inbox = conversation.inbox
    @contact = conversation.contact
  end

  def validate
    errors = []
    rules = merged_rules

    if rules['allowed_deal_stages'].present? && !rules['allowed_deal_stages'].include?(@conversation.deal_stage)
      errors << I18n.t(
        'conversations.resolve_policy.invalid_deal_stage',
        allowed_stages: rules['allowed_deal_stages'].join(', ')
      )
    end

    missing_conversation_attributes = missing_custom_attributes(
      @conversation.custom_attributes,
      rules['required_conversation_custom_attributes']
    )
    if missing_conversation_attributes.present?
      errors << I18n.t(
        'conversations.resolve_policy.missing_conversation_attributes',
        attributes: missing_conversation_attributes.join(', ')
      )
    end

    missing_contact_attributes = missing_custom_attributes(
      @contact.custom_attributes,
      rules['required_contact_custom_attributes']
    )
    if missing_contact_attributes.present?
      errors << I18n.t(
        'conversations.resolve_policy.missing_contact_attributes',
        attributes: missing_contact_attributes.join(', ')
      )
    end

    if @conversation.deal_stage == 'lost' && blank_value?(@conversation.lost_reason)
      errors << I18n.t('conversations.resolve_policy.missing_lost_reason')
    end

    { valid: errors.empty?, errors: errors }
  end

  private

  def merged_rules
    global_rules = @account.settings&.dig('conversation_resolve_rules') || {}
    inbox_rules = @inbox.auto_assignment_config&.dig('resolve_rules') || {}

    merged = DEFAULT_RULES.merge(global_rules).merge(inbox_rules)

    merged['required_conversation_custom_attributes'] = combine_attribute_requirements(
      global_rules['required_conversation_custom_attributes'],
      inbox_rules['required_conversation_custom_attributes']
    )
    merged['required_contact_custom_attributes'] = combine_attribute_requirements(
      global_rules['required_contact_custom_attributes'],
      inbox_rules['required_contact_custom_attributes']
    )

    merged
  end

  def combine_attribute_requirements(global_values, inbox_values)
    [*global_values, *inbox_values].compact.map(&:to_s).uniq
  end

  def missing_custom_attributes(attribute_hash, required_keys)
    safe_hash = attribute_hash.is_a?(Hash) ? attribute_hash : {}
    required_keys.select { |key| blank_value?(safe_hash[key]) }
  end

  def blank_value?(value)
    return true if value.nil?
    return true if value.is_a?(String) && value.strip.empty?
    return true if value.respond_to?(:empty?) && value.empty?

    false
  end
end
