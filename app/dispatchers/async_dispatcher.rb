class AsyncDispatcher < BaseDispatcher
  def dispatch(event_name, timestamp, data)
    EventDispatcherJob.perform_later(event_name, timestamp, sanitize_for_job(data))
  end

  def publish_event(event_name, timestamp, data)
    event_object = Events::Base.new(event_name, timestamp, data)
    publish(event_object.method_name, event_object)
  end

  def listeners
    [
      AutomationRuleListener.instance,
      CampaignListener.instance,
      CsatSurveyListener.instance,
      HookListener.instance,
      InstallationWebhookListener.instance,
      NotificationListener.instance,
      ParticipationListener.instance,
      ReportingEventListener.instance,
      WebhookListener.instance
    ]
  end

  private

  # Sidekiq strict args rejects BigDecimal values in job payloads.
  # We normalize nested BigDecimal values while preserving model objects
  # (serialized by ActiveJob via GlobalID) and other scalar types.
  def sanitize_for_job(value)
    case value
    when Hash
      value.transform_values { |nested| sanitize_for_job(nested) }
    when Array
      value.map { |nested| sanitize_for_job(nested) }
    when BigDecimal
      value.to_f
    else
      value
    end
  end
end

AsyncDispatcher.prepend_mod_with('AsyncDispatcher')
