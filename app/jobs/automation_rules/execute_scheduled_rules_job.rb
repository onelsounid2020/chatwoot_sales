class AutomationRules::ExecuteScheduledRulesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    scheduled_rules.find_each(batch_size: 100) do |rule|
      AutomationRules::PeriodicRulesExecutorService.new(rule).perform
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: rule.account).capture_exception
    end
  end

  private

  def scheduled_rules
    AutomationRule.active.where(event_name: 'periodic_check').includes(:account)
  end
end
