class AutomationRules::PeriodicRulesExecutorService
  BATCH_SIZE = 200

  def initialize(rule, batch_size: BATCH_SIZE)
    @rule = rule
    @account = rule.account
    @batch_size = batch_size
  end

  def perform
    conversations_scope.find_each(batch_size: @batch_size) do |conversation|
      process_conversation(conversation)
    end
  end

  private

  def conversations_scope
    Conversation.where(account_id: @account.id)
  end

  def process_conversation(conversation)
    return unless AutomationRules::ConditionsFilterService.new(@rule, conversation).perform

    AutomationRules::ActionService.new(@rule, @account, conversation).perform
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
  end
end
