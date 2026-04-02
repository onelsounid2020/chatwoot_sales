class V2::Reports::SalesMetricsBuilder
  include DateRangeHelper

  STALE_DAYS = 7
  ACTIVE_STATUSES = %i[open pending snoozed].freeze
  DEFAULT_TREND_WEEKS = 8
  AGING_BUCKETS = [
    { key: '0_7', from: 0, to: 7 },
    { key: '8_14', from: 8, to: 14 },
    { key: '15_30', from: 15, to: 30 },
    { key: '31_plus', from: 31, to: nil }
  ].freeze
  DEFAULT_FORECAST_STAGE_WEIGHTS = {
    'incoming' => 0.10,
    'contacted' => 0.25,
    'qualified' => 0.50,
    'proposal' => 0.75,
    'won' => 1.0,
    'lost' => 0.0
  }.freeze
  FUNNEL_STAGES = %w[incoming contacted qualified proposal won].freeze

  attr_reader :account, :params

  def initialize(account, params)
    @account = account
    @params = params
  end

  def metrics
    {
      total_leads: conversations.count,
      open_opportunities: open_conversations.count,
      won_opportunities: won_conversations.count,
      lost_opportunities: lost_conversations.count,
      win_rate: win_rate,
      pipeline_value: pipeline_value,
      forecast_weighted_value: forecast_weighted_value,
      won_value: won_value,
      stale_opportunities: stale_opportunities,
      avg_open_age_days: avg_open_age_days,
      avg_time_to_close_hours: avg_time_to_close_hours,
      stage_breakdown: stage_breakdown,
      forecast_by_stage: forecast_by_stage,
      funnel_breakdown: funnel_breakdown,
      weekly_trends: weekly_trends,
      aging_breakdown: aging_breakdown,
      top_lost_reasons: top_lost_reasons,
      agent_target_progress: agent_target_progress
    }
  end

  private

  def conversations
    @conversations ||= begin
      scoped = filtered_scope
      range.present? ? scoped.where(created_at: range) : scoped
    end
  end

  def trend_scope
    @trend_scope ||= begin
      scoped = filtered_scope
      if range.present?
        scoped.where(created_at: range)
      else
        scoped.where(created_at: DEFAULT_TREND_WEEKS.weeks.ago..Time.current)
      end
    end
  end

  def filtered_scope
    scoped = account.conversations
    scoped = scoped.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scoped = scoped.where(team_id: params[:team_ids]) if params[:team_ids].present?
    scoped = scoped.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    scoped
  end

  def open_conversations
    @open_conversations ||= conversations.where(status: ACTIVE_STATUSES.map { |status| Conversation.statuses[status] })
  end

  def won_conversations
    @won_conversations ||= conversations.won
  end

  def lost_conversations
    @lost_conversations ||= conversations.lost
  end

  def closed_count
    @closed_count ||= won_conversations.count + lost_conversations.count
  end

  def win_rate
    return 0 if closed_count.zero?

    ((won_conversations.count.to_f / closed_count) * 100).round(2)
  end

  def pipeline_value
    open_conversations.where.not(deal_value_clp: nil).sum(:deal_value_clp).to_f
  end

  def won_value
    won_conversations.where.not(deal_value_clp: nil).sum(:deal_value_clp).to_f
  end

  def forecast_weighted_value
    forecast_by_stage.sum { |row| row[:weighted_value].to_f }.round(2)
  end

  def stale_opportunities
    open_conversations.where('last_activity_at < ?', STALE_DAYS.days.ago).count
  end

  def avg_time_to_close_hours
    return 0 if won_conversations.count.zero?

    seconds = won_conversations.average('EXTRACT(EPOCH FROM (updated_at - created_at))').to_f
    (seconds / 3600.0).round(2)
  end

  def avg_open_age_days
    return 0 if open_conversations.count.zero?

    seconds = open_conversations.average('EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at))').to_f
    (seconds / 86_400.0).round(2)
  end

  def stage_breakdown
    stage_counts = conversations.group(:deal_stage).count
    stage_values = conversations.where.not(deal_value_clp: nil).group(:deal_stage).sum(:deal_value_clp)

    Conversation.deal_stages.keys.map do |stage|
      {
        stage: stage,
        count: stage_metric_value(stage_counts, stage),
        value: stage_metric_value(stage_values, stage).to_f
      }
    end
  end

  def forecast_by_stage
    values = open_conversations.where.not(deal_value_clp: nil).group(:deal_stage).sum(:deal_value_clp)

    forecast_stage_weights.keys.map do |stage|
      raw_value = stage_metric_value(values, stage).to_f
      weight = forecast_stage_weights[stage].to_f
      {
        stage: stage,
        weight: weight,
        raw_value: raw_value,
        weighted_value: (raw_value * weight).round(2)
      }
    end
  end

  def funnel_breakdown
    counts = conversations.group(:deal_stage).count

    previous_count = nil
    FUNNEL_STAGES.map do |stage|
      current_count = stage_metric_value(counts, stage).to_i
      conversion = if previous_count.nil? || previous_count.zero?
                     nil
                   else
                     ((current_count.to_f / previous_count) * 100).round(2)
                   end

      previous_count = current_count
      {
        stage: stage,
        count: current_count,
        conversion_from_previous: conversion
      }
    end
  end

  # PostgreSQL can return grouped enum keys either as integers or as strings,
  # depending on query shape/casting. Resolve both to keep stage metrics stable.
  def stage_metric_value(grouped_values, stage)
    stage_id = Conversation.deal_stages[stage]

    grouped_values[stage] ||
      grouped_values[stage.to_sym] ||
      grouped_values[stage.to_s] ||
      grouped_values[stage_id] ||
      grouped_values[stage_id.to_s] ||
      0
  end

  def weekly_trends
    weeks = trend_scope.group_by_week(:created_at, range: trend_range, default_value: 0).count.keys.sort
    pipeline_by_week = open_trend_scope.group_by_week(:created_at, range: trend_range, default_value: 0).sum(:deal_value_clp)
    won_by_week = trend_scope.won.group_by_week(:created_at, range: trend_range, default_value: 0).count
    lost_by_week = trend_scope.lost.group_by_week(:created_at, range: trend_range, default_value: 0).count

    weeks.map do |week|
      won_count = won_by_week[week].to_i
      lost_count = lost_by_week[week].to_i
      closed_count = won_count + lost_count
      {
        timestamp: week.to_time.to_i,
        pipeline_value: pipeline_by_week[week].to_f,
        win_rate: closed_count.zero? ? 0 : ((won_count.to_f / closed_count) * 100).round(2)
      }
    end
  end

  def open_trend_scope
    trend_scope.where(status: ACTIVE_STATUSES.map { |status| Conversation.statuses[status] }).where.not(deal_value_clp: nil)
  end

  def aging_breakdown
    AGING_BUCKETS.map do |bucket|
      scope = open_conversations.where(aging_bucket_sql(bucket), *aging_bucket_sql_params(bucket))
      {
        bucket: bucket[:key],
        count: scope.count,
        value: scope.where.not(deal_value_clp: nil).sum(:deal_value_clp).to_f
      }
    end
  end

  def top_lost_reasons
    lost_conversations
      .where.not(lost_reason: [nil, ''])
      .group(:lost_reason)
      .order(Arel.sql('COUNT(*) DESC'))
      .limit(5)
      .count
      .map { |reason, count| { reason: reason, count: count } }
  end

  def aging_bucket_sql(bucket)
    if bucket[:to].nil?
      'EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at)) / 86400.0 >= ?'
    else
      'EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at)) / 86400.0 BETWEEN ? AND ?'
    end
  end

  def aging_bucket_sql_params(bucket)
    return [bucket[:from]] if bucket[:to].nil?

    [bucket[:from], bucket[:to]]
  end

  def trend_range
    @trend_range ||= if range.present?
                       parse_date_time(params[:since])..parse_date_time(params[:until])
                     else
                       DEFAULT_TREND_WEEKS.weeks.ago..Time.current
                     end
  end

  def forecast_stage_weights
    @forecast_stage_weights ||= begin
      configured_weights = inbox_forecast_weights || account.settings&.dig('sales_forecast_stage_weights')
      return DEFAULT_FORECAST_STAGE_WEIGHTS if !configured_weights.is_a?(Hash) || configured_weights.empty?

      DEFAULT_FORECAST_STAGE_WEIGHTS.each_with_object({}) do |(stage, default_value), result|
        raw_value = configured_weights[stage] || configured_weights[stage.to_sym]
        result[stage] = normalized_weight(raw_value, default_value)
      end
    end
  end

  def normalized_weight(raw_value, fallback)
    value = Float(raw_value)
    return fallback unless value.finite?

    [[value, 0.0].max, 1.0].min.round(4)
  rescue ArgumentError, TypeError
    fallback
  end

  def inbox_forecast_weights
    return nil if params[:inbox_id].blank?

    inbox = account.inboxes.find_by(id: params[:inbox_id])
    inbox&.auto_assignment_config&.dig('resolve_rules', 'sales_forecast_stage_weights')
  end

  def agent_target_progress
    won_values = won_conversations.where.not(assignee_id: nil).group(:assignee_id).sum(:deal_value_clp)
    configured_targets = sales_agent_targets
    agent_ids = (won_values.keys + configured_targets.keys).uniq
    return [] if agent_ids.empty?

    agents_by_id = User.where(id: agent_ids).pluck(:id, :name).to_h

    agent_ids.map do |agent_id|
      target_value = configured_targets[agent_id].to_f
      won_value = won_values[agent_id].to_f
      attainment = target_value.positive? ? ((won_value / target_value) * 100).round(2) : nil

      {
        agent_id: agent_id,
        agent_name: agents_by_id[agent_id] || "Agent ##{agent_id}",
        target_value: target_value.round(2),
        won_value: won_value.round(2),
        attainment_percent: attainment,
        remaining_value: [target_value - won_value, 0].max.round(2)
      }
    end.sort_by { |row| [-row[:won_value], row[:agent_name].to_s] }
  end

  def sales_agent_targets
    raw_targets = account.settings&.dig('sales_agent_targets_clp')
    return {} unless raw_targets.is_a?(Hash)

    raw_targets.each_with_object({}) do |(agent_id, target), result|
      numeric_target = Float(target)
      next unless numeric_target.finite? && numeric_target >= 0

      result[agent_id.to_i] = numeric_target
    rescue ArgumentError, TypeError
      next
    end
  end
end
