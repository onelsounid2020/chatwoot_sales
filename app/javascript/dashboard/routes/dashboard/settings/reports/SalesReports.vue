<script setup>
import { computed, ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useStore } from 'vuex';
import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';
import ReportHeader from './components/ReportHeader.vue';
import ReportFilters from './components/ReportFilters.vue';
import ReportMetricCard from './components/ReportMetricCard.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import BarChart from 'shared/components/charts/BarChart.vue';
import V4Button from 'dashboard/components-next/button/Button.vue';
import ReportsAPI from 'dashboard/api/reports';
import {
  generateFileName,
  downloadCsvFile,
} from 'dashboard/helper/downloadHelper';
import { REPORTS_EVENTS } from '../../../../helper/AnalyticsHelper/events';

const { t, n } = useI18n();
const store = useStore();
const { currentAccount, updateAccount } = useAccount();

const isLoading = ref(false);
const isSavingTargets = ref(false);
const selectedInbox = ref(null);
const selectedAgent = ref(null);
const salesTargetsDraft = ref({});
const currentRange = ref({ from: null, to: null });
const salesMetrics = ref({
  total_leads: 0,
  open_opportunities: 0,
  won_opportunities: 0,
  lost_opportunities: 0,
  win_rate: 0,
  pipeline_value: 0,
  forecast_weighted_value: 0,
  won_value: 0,
  stale_opportunities: 0,
  avg_open_age_days: 0,
  avg_time_to_close_hours: 0,
  stage_breakdown: [],
  forecast_by_stage: [],
  funnel_breakdown: [],
  weekly_trends: [],
  aging_breakdown: [],
  top_lost_reasons: [],
  agent_target_progress: [],
});

const inboxOptions = computed(() => [
  { id: null, name: t('SALES_REPORTS.FILTERS.ALL_INBOXES') },
  ...(store.getters['inboxes/getInboxes'] || []).map(inbox => ({
    id: inbox.id,
    name: inbox.name,
  })),
]);

const agentOptions = computed(() => [
  { id: null, name: t('SALES_REPORTS.FILTERS.ALL_AGENTS') },
  ...(store.getters['agents/getAgents'] || []).map(agent => ({
    id: agent.id,
    name: agent.name,
    thumbnail: agent.thumbnail,
    availability_status: agent.availability_status,
  })),
]);

const formatCurrency = value =>
  n(value || 0, {
    style: 'currency',
    currency: 'CLP',
    maximumFractionDigits: 2,
  });

const formatPercentage = value =>
  value === null || value === undefined ? '-' : `${value}%`;

const attainmentStatus = value => {
  if (value === null || value === undefined) return 'not_set';
  if (Number(value) >= 100) return 'on_track';
  if (Number(value) >= 60) return 'at_risk';
  return 'off_track';
};

const attainmentLabel = value => {
  switch (attainmentStatus(value)) {
    case 'on_track':
      return t('SALES_REPORTS.TARGETS.STATUS.ON_TRACK');
    case 'at_risk':
      return t('SALES_REPORTS.TARGETS.STATUS.AT_RISK');
    case 'off_track':
      return t('SALES_REPORTS.TARGETS.STATUS.OFF_TRACK');
    default:
      return t('SALES_REPORTS.TARGETS.STATUS.NOT_SET');
  }
};

const attainmentBadgeClass = value => {
  switch (attainmentStatus(value)) {
    case 'on_track':
      return 'bg-emerald-100 text-emerald-800';
    case 'at_risk':
      return 'bg-amber-100 text-amber-800';
    case 'off_track':
      return 'bg-red-100 text-red-800';
    default:
      return 'bg-slate-100 text-slate-700';
  }
};

const stageLabel = stage => {
  switch (stage) {
    case 'contacted':
      return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.CONTACTED');
    case 'qualified':
      return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.QUALIFIED');
    case 'proposal':
      return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.PROPOSAL');
    case 'won':
      return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.WON');
    case 'lost':
      return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.LOST');
    default:
      return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.INCOMING');
  }
};

const agingBucketLabel = bucket => {
  switch (bucket) {
    case '0_7':
      return t('SALES_REPORTS.AGING.BUCKETS.ZERO_TO_SEVEN');
    case '8_14':
      return t('SALES_REPORTS.AGING.BUCKETS.EIGHT_TO_FOURTEEN');
    case '15_30':
      return t('SALES_REPORTS.AGING.BUCKETS.FIFTEEN_TO_THIRTY');
    default:
      return t('SALES_REPORTS.AGING.BUCKETS.THIRTY_ONE_PLUS');
  }
};

const metricCards = computed(() => [
  {
    key: 'total_leads',
    label: t('SALES_REPORTS.METRICS.TOTAL_LEADS.LABEL'),
    infoText: t('SALES_REPORTS.METRICS.TOTAL_LEADS.TOOLTIP'),
    value: String(salesMetrics.value.total_leads || 0),
  },
  {
    key: 'open_opportunities',
    label: t('SALES_REPORTS.METRICS.OPEN_OPPORTUNITIES.LABEL'),
    infoText: t('SALES_REPORTS.METRICS.OPEN_OPPORTUNITIES.TOOLTIP'),
    value: String(salesMetrics.value.open_opportunities || 0),
  },
  {
    key: 'win_rate',
    label: t('SALES_REPORTS.METRICS.WIN_RATE.LABEL'),
    infoText: t('SALES_REPORTS.METRICS.WIN_RATE.TOOLTIP'),
    value: `${salesMetrics.value.win_rate || 0}%`,
  },
  {
    key: 'pipeline_value',
    label: t('SALES_REPORTS.METRICS.PIPELINE_VALUE.LABEL'),
    infoText: t('SALES_REPORTS.METRICS.PIPELINE_VALUE.TOOLTIP'),
    value: formatCurrency(salesMetrics.value.pipeline_value),
  },
  {
    key: 'forecast_weighted_value',
    label: t('SALES_REPORTS.METRICS.FORECAST_WEIGHTED_VALUE.LABEL'),
    infoText: t('SALES_REPORTS.METRICS.FORECAST_WEIGHTED_VALUE.TOOLTIP'),
    value: formatCurrency(salesMetrics.value.forecast_weighted_value),
  },
  {
    key: 'won_value',
    label: t('SALES_REPORTS.METRICS.WON_VALUE.LABEL'),
    infoText: t('SALES_REPORTS.METRICS.WON_VALUE.TOOLTIP'),
    value: formatCurrency(salesMetrics.value.won_value),
  },
  {
    key: 'stale_opportunities',
    label: t('SALES_REPORTS.METRICS.STALE_OPPORTUNITIES.LABEL'),
    infoText: t('SALES_REPORTS.METRICS.STALE_OPPORTUNITIES.TOOLTIP'),
    value: String(salesMetrics.value.stale_opportunities || 0),
  },
  {
    key: 'avg_open_age_days',
    label: t('SALES_REPORTS.METRICS.AVG_OPEN_AGE_DAYS.LABEL'),
    infoText: t('SALES_REPORTS.METRICS.AVG_OPEN_AGE_DAYS.TOOLTIP'),
    value: `${salesMetrics.value.avg_open_age_days || 0}d`,
  },
]);

const trendLabels = computed(() =>
  (salesMetrics.value.weekly_trends || []).map(point =>
    format(fromUnixTime(point.timestamp), 'dd-MMM')
  )
);

const pipelineTrendCollection = computed(() => ({
  labels: trendLabels.value,
  datasets: [
    {
      type: 'line',
      borderColor: '#1f93ff',
      pointBackgroundColor: '#1f93ff',
      data: (salesMetrics.value.weekly_trends || []).map(
        point => point.pipeline_value
      ),
      tension: 0.3,
      fill: false,
    },
  ],
}));

const winRateTrendCollection = computed(() => ({
  labels: trendLabels.value,
  datasets: [
    {
      type: 'line',
      borderColor: '#0ea5a3',
      pointBackgroundColor: '#0ea5a3',
      data: (salesMetrics.value.weekly_trends || []).map(
        point => point.win_rate
      ),
      tension: 0.3,
      fill: false,
    },
  ],
}));

const hasTrends = computed(
  () => (salesMetrics.value.weekly_trends || []).length
);
const hasAgingBreakdown = computed(
  () => (salesMetrics.value.aging_breakdown || []).length
);
const hasLostReasons = computed(
  () => (salesMetrics.value.top_lost_reasons || []).length
);
const hasForecastByStage = computed(
  () => (salesMetrics.value.forecast_by_stage || []).length
);
const hasFunnelBreakdown = computed(
  () => (salesMetrics.value.funnel_breakdown || []).length
);

const salesAgentRows = computed(() => {
  const accountTargets =
    currentAccount.value?.settings?.sales_agent_targets_clp || {};
  const agents = store.getters['agents/getAgents'] || [];
  const rowsFromMetrics = (salesMetrics.value.agent_target_progress || []).map(
    row => ({
      agent_id: row.agent_id,
      agent_name: row.agent_name,
      target_value: row.target_value,
      won_value: row.won_value,
      attainment_percent: row.attainment_percent,
      remaining_value: row.remaining_value,
    })
  );

  const rowIds = new Set(rowsFromMetrics.map(row => Number(row.agent_id)));
  const rowsFromTargets = agents
    .filter(agent =>
      Object.prototype.hasOwnProperty.call(accountTargets, String(agent.id))
    )
    .map(agent => ({
      agent_id: agent.id,
      agent_name: agent.name,
      target_value: Number(accountTargets[String(agent.id)] || 0),
      won_value: 0,
      attainment_percent: null,
      remaining_value: Number(accountTargets[String(agent.id)] || 0),
    }))
    .filter(row => !rowIds.has(Number(row.agent_id)));

  return [...rowsFromMetrics, ...rowsFromTargets].sort((a, b) =>
    a.agent_name.localeCompare(b.agent_name)
  );
});
const hasAgentTargetProgress = computed(() => salesAgentRows.value.length);

const syncSalesTargetsDraft = () => {
  const accountTargets =
    currentAccount.value?.settings?.sales_agent_targets_clp || {};
  salesTargetsDraft.value = salesAgentRows.value.reduce((acc, row) => {
    const existing = accountTargets[String(row.agent_id)];
    acc[String(row.agent_id)] =
      existing !== undefined ? Number(existing) : Number(row.target_value || 0);
    return acc;
  }, {});
};

watch([salesAgentRows, currentAccount], () => {
  syncSalesTargetsDraft();
});

const trendChartOptions = {
  scales: {
    x: {
      grid: { drawOnChartArea: false },
    },
    y: {
      beginAtZero: true,
      grid: { drawOnChartArea: false },
    },
  },
};

const winRateChartOptions = {
  ...trendChartOptions,
  scales: {
    ...trendChartOptions.scales,
    y: {
      ...trendChartOptions.scales.y,
      ticks: {
        callback: value => `${value}%`,
      },
      max: 100,
    },
  },
};

const fetchSalesMetrics = async ({ from, to }) => {
  currentRange.value = { from, to };
  isLoading.value = true;
  try {
    const { data } = await ReportsAPI.getSalesMetrics({
      from,
      to,
      inboxId: selectedInbox.value?.id,
      assigneeId: selectedAgent.value?.id,
    });
    salesMetrics.value = data;
  } catch {
    useAlert(t('SALES_REPORTS.API.FETCH_FAILED'));
  } finally {
    isLoading.value = false;
  }
};

const onInboxFilterSelect = item => {
  selectedInbox.value = item && item.id !== null ? item : null;
  if (currentRange.value.from && currentRange.value.to) {
    fetchSalesMetrics(currentRange.value);
  }
};

const onAgentFilterSelect = item => {
  selectedAgent.value = item && item.id !== null ? item : null;
  if (currentRange.value.from && currentRange.value.to) {
    fetchSalesMetrics(currentRange.value);
  }
};

const downloadSalesReport = async () => {
  if (!currentRange.value.from || !currentRange.value.to) return;

  try {
    const fileName = generateFileName({
      type: 'sales',
      to: currentRange.value.to,
      businessHours: false,
    });
    const { data } = await ReportsAPI.getSalesSummaryReports({
      from: currentRange.value.from,
      to: currentRange.value.to,
      inboxId: selectedInbox.value?.id,
      assigneeId: selectedAgent.value?.id,
    });
    downloadCsvFile(fileName, data);
    useTrack(REPORTS_EVENTS.DOWNLOAD_REPORT, {
      reportType: 'sales_summary',
      businessHours: false,
    });
  } catch {
    useAlert(t('SALES_REPORTS.API.DOWNLOAD_FAILED'));
  }
};

const saveAgentTargets = async () => {
  const payload = Object.entries(salesTargetsDraft.value).reduce(
    (acc, [agentId, value]) => {
      const numericValue = Number(value);
      if (!Number.isNaN(numericValue) && numericValue >= 0) {
        acc[agentId] = numericValue;
      }
      return acc;
    },
    {}
  );

  try {
    isSavingTargets.value = true;
    await updateAccount({ sales_agent_targets_clp: payload }, { silent: true });
    useAlert(t('SALES_REPORTS.TARGETS.SAVE_SUCCESS'));
    syncSalesTargetsDraft();
    if (currentRange.value.from && currentRange.value.to) {
      await fetchSalesMetrics(currentRange.value);
    }
  } catch {
    useAlert(t('SALES_REPORTS.TARGETS.SAVE_ERROR'));
  } finally {
    isSavingTargets.value = false;
  }
};

onMounted(() => {
  Promise.all([
    store.dispatch('inboxes/get'),
    store.dispatch('agents/get'),
  ]).then(() => {
    syncSalesTargetsDraft();
  });
});
</script>

<template>
  <ReportHeader
    :header-title="$t('SALES_REPORTS.HEADER')"
    :header-description="$t('SALES_REPORTS.DESCRIPTION')"
  >
    <V4Button
      :label="$t('SALES_REPORTS.DOWNLOAD')"
      icon="i-ph-download-simple"
      size="sm"
      @click="downloadSalesReport"
    />
  </ReportHeader>
  <div class="flex flex-col gap-4 pb-6">
    <ReportFilters
      :show-entity-filter="false"
      :show-group-by="false"
      :show-business-hours="false"
      @filter-change="fetchSalesMetrics"
    />
    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
      <MultiselectDropdown
        :options="inboxOptions"
        :selected-item="selectedInbox"
        :has-thumbnail="false"
        :multiselector-title="$t('SALES_REPORTS.FILTERS.INBOX_LABEL')"
        :multiselector-placeholder="$t('SALES_REPORTS.FILTERS.ALL_INBOXES')"
        :no-search-result="$t('SALES_REPORTS.FILTERS.NO_RESULTS')"
        :input-placeholder="$t('SALES_REPORTS.FILTERS.SEARCH_INBOX')"
        @select="onInboxFilterSelect"
      />
      <MultiselectDropdown
        :options="agentOptions"
        :selected-item="selectedAgent"
        :multiselector-title="$t('SALES_REPORTS.FILTERS.AGENT_LABEL')"
        :multiselector-placeholder="$t('SALES_REPORTS.FILTERS.ALL_AGENTS')"
        :no-search-result="$t('SALES_REPORTS.FILTERS.NO_RESULTS')"
        :input-placeholder="$t('SALES_REPORTS.FILTERS.SEARCH_AGENT')"
        @select="onAgentFilterSelect"
      />
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
      <div
        v-for="metric in metricCards"
        :key="metric.key"
        class="bg-n-slate-1 rounded-lg border border-n-weak p-4"
      >
        <ReportMetricCard
          :label="metric.label"
          :value="metric.value"
          :info-text="metric.infoText"
          :disabled="isLoading"
        />
      </div>
    </div>

    <div class="bg-n-slate-1 rounded-lg border border-n-weak p-4">
      <div class="flex items-start justify-between gap-4 mb-3">
        <div>
          <h3 class="text-base font-medium text-n-slate-12">
            {{ $t('SALES_REPORTS.TARGETS.TITLE') }}
          </h3>
          <p class="text-sm text-n-slate-11 mb-0">
            {{ $t('SALES_REPORTS.TARGETS.DESCRIPTION') }}
          </p>
        </div>
        <V4Button
          :label="$t('SALES_REPORTS.TARGETS.SAVE_BUTTON')"
          size="sm"
          :is-loading="isSavingTargets"
          @click="saveAgentTargets"
        />
      </div>
      <div v-if="hasAgentTargetProgress" class="overflow-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-n-slate-11 border-b border-n-weak">
              <th class="py-2 pr-3">
                {{ $t('SALES_REPORTS.TARGETS.AGENT') }}
              </th>
              <th class="py-2 pr-3">
                {{ $t('SALES_REPORTS.TARGETS.TARGET') }}
              </th>
              <th class="py-2 pr-3">
                {{ $t('SALES_REPORTS.TARGETS.WON_VALUE') }}
              </th>
              <th class="py-2 pr-3">
                {{ $t('SALES_REPORTS.TARGETS.REMAINING') }}
              </th>
              <th class="py-2">
                {{ $t('SALES_REPORTS.TARGETS.ATTAINMENT') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in salesAgentRows"
              :key="`sales-target-${row.agent_id}`"
              class="border-b border-n-weak/50 last:border-transparent"
            >
              <td class="py-2 pr-3 text-n-slate-12">
                {{ row.agent_name }}
              </td>
              <td class="py-2 pr-3 min-w-44">
                <woot-input
                  v-model.number="salesTargetsDraft[String(row.agent_id)]"
                  type="number"
                  min="0"
                  :placeholder="$t('SALES_REPORTS.TARGETS.TARGET_PLACEHOLDER')"
                />
              </td>
              <td class="py-2 pr-3 text-n-slate-12">
                {{ formatCurrency(row.won_value) }}
              </td>
              <td class="py-2 pr-3 text-n-slate-12">
                {{ formatCurrency(row.remaining_value) }}
              </td>
              <td class="py-2 text-n-slate-12">
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
                  :class="attainmentBadgeClass(row.attainment_percent)"
                >
                  {{ attainmentLabel(row.attainment_percent) }}
                </span>
                <div class="mt-1 text-xs text-n-slate-11">
                  {{
                    row.attainment_percent === null
                      ? $t('SALES_REPORTS.TARGETS.NOT_SET')
                      : formatPercentage(row.attainment_percent)
                  }}
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div
        v-else
        class="h-24 flex items-center justify-center text-sm text-n-slate-10"
      >
        {{ $t('SALES_REPORTS.TRENDS.NO_DATA') }}
      </div>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
      <div class="bg-n-slate-1 rounded-lg border border-n-weak p-4">
        <h3 class="text-base font-medium text-n-slate-12 mb-3">
          {{ $t('SALES_REPORTS.TRENDS.PIPELINE_VALUE_TITLE') }}
        </h3>
        <div class="h-64">
          <BarChart
            v-if="hasTrends"
            :collection="pipelineTrendCollection"
            :chart-options="trendChartOptions"
          />
          <div
            v-else
            class="h-full flex items-center justify-center text-sm text-n-slate-10"
          >
            {{ $t('SALES_REPORTS.TRENDS.NO_DATA') }}
          </div>
        </div>
      </div>
      <div class="bg-n-slate-1 rounded-lg border border-n-weak p-4">
        <h3 class="text-base font-medium text-n-slate-12 mb-3">
          {{ $t('SALES_REPORTS.TRENDS.WIN_RATE_TITLE') }}
        </h3>
        <div class="h-64">
          <BarChart
            v-if="hasTrends"
            :collection="winRateTrendCollection"
            :chart-options="winRateChartOptions"
          />
          <div
            v-else
            class="h-full flex items-center justify-center text-sm text-n-slate-10"
          >
            {{ $t('SALES_REPORTS.TRENDS.NO_DATA') }}
          </div>
        </div>
      </div>
    </div>

    <div class="bg-n-slate-1 rounded-lg border border-n-weak p-4">
      <h3 class="text-base font-medium text-n-slate-12 mb-3">
        {{ $t('SALES_REPORTS.STAGE_BREAKDOWN.TITLE') }}
      </h3>
      <div class="overflow-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-n-slate-11 border-b border-n-weak">
              <th class="py-2 pr-3">
                {{ $t('SALES_REPORTS.STAGE_BREAKDOWN.STAGE') }}
              </th>
              <th class="py-2 pr-3">
                {{ $t('SALES_REPORTS.STAGE_BREAKDOWN.COUNT') }}
              </th>
              <th class="py-2">
                {{ $t('SALES_REPORTS.STAGE_BREAKDOWN.VALUE') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in salesMetrics.stage_breakdown"
              :key="row.stage"
              class="border-b border-n-weak/50 last:border-transparent"
            >
              <td class="py-2 pr-3 text-n-slate-12">
                {{ stageLabel(row.stage) }}
              </td>
              <td class="py-2 pr-3 text-n-slate-12">
                {{ row.count || 0 }}
              </td>
              <td class="py-2 text-n-slate-12">
                {{ formatCurrency(row.value) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
      <div class="bg-n-slate-1 rounded-lg border border-n-weak p-4">
        <h3 class="text-base font-medium text-n-slate-12 mb-3">
          {{ $t('SALES_REPORTS.FORECAST.TITLE') }}
        </h3>
        <div v-if="hasForecastByStage" class="overflow-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-n-slate-11 border-b border-n-weak">
                <th class="py-2 pr-3">
                  {{ $t('SALES_REPORTS.FORECAST.STAGE') }}
                </th>
                <th class="py-2 pr-3">
                  {{ $t('SALES_REPORTS.FORECAST.WEIGHT') }}
                </th>
                <th class="py-2 pr-3">
                  {{ $t('SALES_REPORTS.FORECAST.RAW_VALUE') }}
                </th>
                <th class="py-2">
                  {{ $t('SALES_REPORTS.FORECAST.WEIGHTED_VALUE') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in salesMetrics.forecast_by_stage"
                :key="row.stage"
                class="border-b border-n-weak/50 last:border-transparent"
              >
                <td class="py-2 pr-3 text-n-slate-12">
                  {{ stageLabel(row.stage) }}
                </td>
                <td class="py-2 pr-3 text-n-slate-12">
                  {{ formatPercentage((row.weight || 0) * 100) }}
                </td>
                <td class="py-2 pr-3 text-n-slate-12">
                  {{ formatCurrency(row.raw_value) }}
                </td>
                <td class="py-2 text-n-slate-12">
                  {{ formatCurrency(row.weighted_value) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div
          v-else
          class="h-24 flex items-center justify-center text-sm text-n-slate-10"
        >
          {{ $t('SALES_REPORTS.TRENDS.NO_DATA') }}
        </div>
      </div>

      <div class="bg-n-slate-1 rounded-lg border border-n-weak p-4">
        <h3 class="text-base font-medium text-n-slate-12 mb-3">
          {{ $t('SALES_REPORTS.FUNNEL.TITLE') }}
        </h3>
        <div v-if="hasFunnelBreakdown" class="overflow-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-n-slate-11 border-b border-n-weak">
                <th class="py-2 pr-3">
                  {{ $t('SALES_REPORTS.FUNNEL.STAGE') }}
                </th>
                <th class="py-2 pr-3">
                  {{ $t('SALES_REPORTS.FUNNEL.COUNT') }}
                </th>
                <th class="py-2">
                  {{ $t('SALES_REPORTS.FUNNEL.CONVERSION_FROM_PREVIOUS') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in salesMetrics.funnel_breakdown"
                :key="row.stage"
                class="border-b border-n-weak/50 last:border-transparent"
              >
                <td class="py-2 pr-3 text-n-slate-12">
                  {{ stageLabel(row.stage) }}
                </td>
                <td class="py-2 pr-3 text-n-slate-12">{{ row.count || 0 }}</td>
                <td class="py-2 text-n-slate-12">
                  {{ formatPercentage(row.conversion_from_previous) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div
          v-else
          class="h-24 flex items-center justify-center text-sm text-n-slate-10"
        >
          {{ $t('SALES_REPORTS.TRENDS.NO_DATA') }}
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
      <div class="bg-n-slate-1 rounded-lg border border-n-weak p-4">
        <h3 class="text-base font-medium text-n-slate-12 mb-3">
          {{ $t('SALES_REPORTS.AGING.TITLE') }}
        </h3>
        <div v-if="hasAgingBreakdown" class="overflow-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-n-slate-11 border-b border-n-weak">
                <th class="py-2 pr-3">
                  {{ $t('SALES_REPORTS.AGING.BUCKET') }}
                </th>
                <th class="py-2 pr-3">{{ $t('SALES_REPORTS.AGING.COUNT') }}</th>
                <th class="py-2">{{ $t('SALES_REPORTS.AGING.VALUE') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in salesMetrics.aging_breakdown"
                :key="row.bucket"
                class="border-b border-n-weak/50 last:border-transparent"
              >
                <td class="py-2 pr-3 text-n-slate-12">
                  {{ agingBucketLabel(row.bucket) }}
                </td>
                <td class="py-2 pr-3 text-n-slate-12">{{ row.count || 0 }}</td>
                <td class="py-2 text-n-slate-12">
                  {{ formatCurrency(row.value) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div
          v-else
          class="h-24 flex items-center justify-center text-sm text-n-slate-10"
        >
          {{ $t('SALES_REPORTS.TRENDS.NO_DATA') }}
        </div>
      </div>

      <div class="bg-n-slate-1 rounded-lg border border-n-weak p-4">
        <h3 class="text-base font-medium text-n-slate-12 mb-3">
          {{ $t('SALES_REPORTS.LOST_REASONS.TITLE') }}
        </h3>
        <div v-if="hasLostReasons" class="overflow-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-n-slate-11 border-b border-n-weak">
                <th class="py-2 pr-3">
                  {{ $t('SALES_REPORTS.LOST_REASONS.REASON') }}
                </th>
                <th class="py-2">
                  {{ $t('SALES_REPORTS.LOST_REASONS.COUNT') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in salesMetrics.top_lost_reasons"
                :key="`${row.reason}-${row.count}`"
                class="border-b border-n-weak/50 last:border-transparent"
              >
                <td class="py-2 pr-3 text-n-slate-12">{{ row.reason }}</td>
                <td class="py-2 text-n-slate-12">{{ row.count }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div
          v-else
          class="h-24 flex items-center justify-center text-sm text-n-slate-10"
        >
          {{ $t('SALES_REPORTS.TRENDS.NO_DATA') }}
        </div>
      </div>
    </div>
  </div>
</template>
