<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ConversationApi from 'dashboard/api/inbox/conversation';

const { t } = useI18n();

const isLoading = ref(false);
const conversations = ref([]);
const selectedFollowUpFilter = ref('all');

const STAGES = [
  'incoming',
  'contacted',
  'qualified',
  'proposal',
  'won',
  'lost',
];
const stageTitle = stage => {
  if (stage === 'incoming') return t('CONTACTS_LAYOUT.SALES.STAGES.INCOMING');
  if (stage === 'contacted') return t('CONTACTS_LAYOUT.SALES.STAGES.CONTACTED');
  if (stage === 'qualified') return t('CONTACTS_LAYOUT.SALES.STAGES.QUALIFIED');
  if (stage === 'proposal') return t('CONTACTS_LAYOUT.SALES.STAGES.PROPOSAL');
  if (stage === 'won') return t('CONTACTS_LAYOUT.SALES.STAGES.WON');
  if (stage === 'lost') return t('CONTACTS_LAYOUT.SALES.STAGES.LOST');
  return stage;
};

const followUpStatus = conversation => {
  const nextFollowUpAt = conversation?.next_follow_up_at;
  if (!nextFollowUpAt) return 'missing';

  const lastContactedAt = Number(conversation?.last_contacted_at || 0);
  if (lastContactedAt && lastContactedAt >= Number(nextFollowUpAt)) {
    return 'completed';
  }

  const now = Math.floor(Date.now() / 1000);
  const diffInSeconds = Number(nextFollowUpAt) - now;

  if (diffInSeconds < 0) return 'overdue';
  if (diffInSeconds <= 24 * 60 * 60) return 'today';
  return 'scheduled';
};

const followUpPriority = status => {
  if (status === 'overdue') return 0;
  if (status === 'today') return 1;
  if (status === 'missing') return 2;
  if (status === 'scheduled') return 3;
  return 4;
};

const conversationPriority = conversation => {
  return followUpPriority(followUpStatus(conversation));
};

const followUpFilterOptions = computed(() => [
  { id: 'all', label: t('CONTACTS_LAYOUT.SALES_PIPELINE.FILTERS.ALL') },
  {
    id: 'overdue',
    label: t('CONTACTS_LAYOUT.SALES_PIPELINE.FILTERS.OVERDUE'),
  },
  { id: 'today', label: t('CONTACTS_LAYOUT.SALES_PIPELINE.FILTERS.TODAY') },
  {
    id: 'missing',
    label: t('CONTACTS_LAYOUT.SALES_PIPELINE.FILTERS.MISSING'),
  },
  {
    id: 'completed',
    label: t('CONTACTS_LAYOUT.SALES_PIPELINE.FILTERS.COMPLETED'),
  },
  {
    id: 'scheduled',
    label: t('CONTACTS_LAYOUT.SALES_PIPELINE.FILTERS.SCHEDULED'),
  },
]);

const filteredConversations = computed(() => {
  if (selectedFollowUpFilter.value === 'all') {
    return conversations.value;
  }

  return conversations.value.filter(
    conversation =>
      followUpStatus(conversation) === selectedFollowUpFilter.value
  );
});

const followUpFilterCount = filterId => {
  if (filterId === 'all') return conversations.value.length;
  return conversations.value.filter(
    conversation => followUpStatus(conversation) === filterId
  ).length;
};

const sumDealValueByCurrency = currencyCode => {
  return filteredConversations.value
    .filter(
      conversation => (conversation?.deal_currency || 'CLP') === currencyCode
    )
    .reduce((total, conversation) => {
      const value = Number(conversation?.deal_value);
      return Number.isNaN(value) ? total : total + value;
    }, 0);
};

const formatCurrencyAmount = (amount, currencyCode) => {
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: currencyCode,
    maximumFractionDigits: 2,
  }).format(amount);
};

const pipelineMetrics = computed(() => {
  const overdueCount = filteredConversations.value.filter(
    conversation => followUpStatus(conversation) === 'overdue'
  ).length;
  const missingCount = filteredConversations.value.filter(
    conversation => followUpStatus(conversation) === 'missing'
  ).length;
  const completedCount = filteredConversations.value.filter(
    conversation => followUpStatus(conversation) === 'completed'
  ).length;

  return [
    {
      key: 'opportunities',
      label: t('CONTACTS_LAYOUT.SALES_PIPELINE.METRICS.OPPORTUNITIES'),
      value: filteredConversations.value.length,
    },
    {
      key: 'overdue',
      label: t('CONTACTS_LAYOUT.SALES_PIPELINE.METRICS.OVERDUE'),
      value: overdueCount,
    },
    {
      key: 'missing',
      label: t('CONTACTS_LAYOUT.SALES_PIPELINE.METRICS.MISSING'),
      value: missingCount,
    },
    {
      key: 'completed',
      label: t('CONTACTS_LAYOUT.SALES_PIPELINE.METRICS.COMPLETED'),
      value: completedCount,
    },
    {
      key: 'value_clp',
      label: t('CONTACTS_LAYOUT.SALES_PIPELINE.METRICS.VALUE_CLP'),
      value: formatCurrencyAmount(sumDealValueByCurrency('CLP'), 'CLP'),
    },
    {
      key: 'value_usd',
      label: t('CONTACTS_LAYOUT.SALES_PIPELINE.METRICS.VALUE_USD'),
      value: formatCurrencyAmount(sumDealValueByCurrency('USD'), 'USD'),
    },
  ];
});

const groupedConversations = computed(() => {
  return STAGES.reduce((acc, stage) => {
    acc[stage] = filteredConversations.value
      .filter(conversation => (conversation.deal_stage || 'incoming') === stage)
      .sort((a, b) => {
        const priorityDiff = conversationPriority(a) - conversationPriority(b);
        if (priorityDiff !== 0) return priorityDiff;

        const aFollowUp = Number(a?.next_follow_up_at || 0);
        const bFollowUp = Number(b?.next_follow_up_at || 0);
        if (aFollowUp !== bFollowUp) return aFollowUp - bFollowUp;

        return (
          Number(b?.last_activity_at || 0) - Number(a?.last_activity_at || 0)
        );
      });
    return acc;
  }, {});
});

const asCurrency = (value, currency = 'USD') => {
  if (value === null || value === undefined || value === '') {
    return t('CONTACTS_LAYOUT.SALES_PIPELINE.NO_VALUE');
  }

  const numericValue = Number(value);
  if (Number.isNaN(numericValue)) {
    return t('CONTACTS_LAYOUT.SALES_PIPELINE.NO_VALUE');
  }

  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency,
    maximumFractionDigits: 2,
  }).format(numericValue);
};

const followUpStatusLabel = conversation => {
  const status = followUpStatus(conversation);
  if (status === 'overdue') {
    return t('CONTACTS_LAYOUT.SALES_PIPELINE.FOLLOW_UP_STATUS.OVERDUE');
  }
  if (status === 'today') {
    return t('CONTACTS_LAYOUT.SALES_PIPELINE.FOLLOW_UP_STATUS.TODAY');
  }
  if (status === 'missing') {
    return t('CONTACTS_LAYOUT.SALES_PIPELINE.FOLLOW_UP_STATUS.MISSING');
  }
  if (status === 'completed') {
    return t('CONTACTS_LAYOUT.SALES_PIPELINE.FOLLOW_UP_STATUS.COMPLETED');
  }
  return t('CONTACTS_LAYOUT.SALES_PIPELINE.FOLLOW_UP_STATUS.SCHEDULED');
};

const followUpStatusClass = conversation => {
  const status = followUpStatus(conversation);

  if (status === 'overdue') {
    return 'border-n-ruby-6 bg-n-ruby-3 text-n-ruby-11';
  }
  if (status === 'today') {
    return 'border-n-amber-6 bg-n-amber-3 text-n-amber-12';
  }
  if (status === 'missing') {
    return 'border-n-slate-6 bg-n-alpha-2 text-n-slate-11';
  }
  if (status === 'completed') {
    return 'border-n-teal-6 bg-n-teal-3 text-n-teal-12';
  }

  return 'border-n-sky-6 bg-n-sky-3 text-n-sky-12';
};

const conversationLabel = conversation => {
  const senderName = conversation?.meta?.sender?.name;
  return senderName || `#${conversation.id}`;
};

const formatFollowUpAt = conversation => {
  const timestamp = Number(conversation?.next_follow_up_at);
  if (!timestamp) {
    return t('CONTACTS_LAYOUT.SALES_PIPELINE.NO_FOLLOW_UP_DATE');
  }

  const date = new Date(timestamp * 1000);
  if (Number.isNaN(date.getTime())) {
    return t('CONTACTS_LAYOUT.SALES_PIPELINE.NO_FOLLOW_UP_DATE');
  }

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
};

const openConversation = conversation => {
  const accountId = conversation?.account_id;
  const conversationId = conversation?.id;
  if (!accountId || !conversationId) return;

  window.open(
    `/app/accounts/${accountId}/conversations/${conversationId}`,
    '_blank',
    'noopener'
  );
};

const loadConversations = async () => {
  isLoading.value = true;

  try {
    const fetched = [];
    const maxPages = 20;

    for (let page = 1; page <= maxPages; page += 1) {
      // eslint-disable-next-line no-await-in-loop
      const response = await ConversationApi.get({
        page,
        status: 'all',
        assigneeType: 'all',
        sortBy: 'last_activity_at_desc',
      });

      const payload = response?.data?.data?.payload || [];
      if (!payload.length) break;

      fetched.push(...payload);

      const allCount = response?.data?.data?.meta?.all_count || 0;
      if (allCount > 0 && fetched.length >= allCount) break;
    }

    conversations.value = fetched;
  } catch (error) {
    useAlert(t('CONTACTS_LAYOUT.SALES_PIPELINE.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const moveToStage = async (conversation, targetStage) => {
  if ((conversation.deal_stage || 'incoming') === targetStage) return;

  const previousStage = conversation.deal_stage || 'incoming';
  conversation.deal_stage = targetStage;

  try {
    await ConversationApi.updateSalesInfo({
      conversationId: conversation.id,
      dealStage: targetStage,
      dealValue: conversation.deal_value,
      dealCurrency: conversation.deal_currency || 'CLP',
      nextFollowUpAt: conversation.next_follow_up_at,
      lastContactedAt: conversation.last_contacted_at,
    });
  } catch (error) {
    conversation.deal_stage = previousStage;
    useAlert(t('CONTACTS_LAYOUT.SALES_PIPELINE.UPDATE_ERROR'));
  }
};

onMounted(() => {
  loadConversations();
});
</script>

<template>
  <section class="flex flex-col gap-4 p-4">
    <header class="flex items-center justify-between">
      <div class="flex flex-col gap-1">
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('CONTACTS_LAYOUT.SALES_PIPELINE.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('CONTACTS_LAYOUT.SALES_PIPELINE.SUBTITLE') }}
        </p>
      </div>
    </header>

    <div class="flex flex-wrap items-center gap-2">
      <button
        v-for="option in followUpFilterOptions"
        :key="option.id"
        type="button"
        class="px-3 py-1.5 rounded-full text-xs border transition-colors"
        :class="
          selectedFollowUpFilter === option.id
            ? 'border-n-brand bg-n-alpha-2 text-n-brand'
            : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2'
        "
        @click="selectedFollowUpFilter = option.id"
      >
        {{
          t('CONTACTS_LAYOUT.SALES_PIPELINE.FILTERS_WITH_COUNT', {
            label: option.label,
            count: followUpFilterCount(option.id),
          })
        }}
      </button>
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-6 gap-2">
      <article
        v-for="metric in pipelineMetrics"
        :key="metric.key"
        class="rounded-lg border border-n-weak bg-n-solid-1 p-3"
      >
        <p class="text-xs text-n-slate-11 mb-1">
          {{ metric.label }}
        </p>
        <p class="text-base font-semibold text-n-slate-12">
          {{ metric.value }}
        </p>
      </article>
    </div>

    <div
      v-if="isLoading"
      class="grid place-items-center h-40 rounded-xl border border-n-weak bg-n-solid-1"
    >
      <span class="text-sm text-n-slate-11">
        {{ t('CONTACTS_LAYOUT.SALES_PIPELINE.LOADING') }}
      </span>
    </div>

    <div
      v-else
      class="grid grid-cols-[repeat(6,minmax(260px,1fr))] gap-3 overflow-x-auto pb-1"
    >
      <section
        v-for="stage in STAGES"
        :key="stage"
        class="flex flex-col gap-3 p-3 rounded-xl border border-n-weak bg-n-alpha-1 min-h-[380px]"
      >
        <div class="flex items-center justify-between">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ stageTitle(stage) }}
          </h2>
          <span class="text-xs text-n-slate-10">
            {{ groupedConversations[stage]?.length || 0 }}
          </span>
        </div>

        <div class="flex flex-col gap-2">
          <article
            v-for="conversation in groupedConversations[stage]"
            :key="conversation.id"
            class="flex flex-col gap-2 p-3 rounded-lg border border-n-weak bg-n-background"
          >
            <div class="flex items-center justify-between gap-2">
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{ conversationLabel(conversation) }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{ `#${conversation.id}` }}
              </span>
            </div>

            <div class="text-xs text-n-slate-11">
              {{ conversation?.meta?.channel || '-' }}
            </div>

            <div class="text-sm font-semibold text-n-slate-12">
              {{
                asCurrency(
                  conversation.deal_value,
                  conversation.deal_currency || 'CLP'
                )
              }}
            </div>

            <div class="flex items-center gap-2">
              <span
                class="text-[11px] px-2 py-0.5 rounded-md border font-medium"
                :class="followUpStatusClass(conversation)"
              >
                {{ followUpStatusLabel(conversation) }}
              </span>
            </div>
            <p class="text-xs text-n-slate-11">
              {{
                t('CONTACTS_LAYOUT.SALES_PIPELINE.NEXT_FOLLOW_UP_AT', {
                  datetime: formatFollowUpAt(conversation),
                })
              }}
            </p>

            <div class="flex flex-wrap gap-1">
              <button
                v-for="targetStage in STAGES"
                :key="`${conversation.id}-${targetStage}`"
                type="button"
                class="px-2 py-1 text-xs rounded-md border transition-colors"
                :class="
                  (conversation.deal_stage || 'incoming') === targetStage
                    ? 'border-n-brand text-n-brand bg-n-alpha-2'
                    : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2'
                "
                @click="moveToStage(conversation, targetStage)"
              >
                {{ stageTitle(targetStage) }}
              </button>
            </div>

            <button
              type="button"
              class="mt-1 px-2 py-1 text-xs rounded-md border border-n-weak text-n-slate-11 hover:bg-n-alpha-2 self-start"
              @click="openConversation(conversation)"
            >
              {{ t('CONTACTS_LAYOUT.SALES_PIPELINE.OPEN_CONVERSATION') }}
            </button>
          </article>

          <div
            v-if="!groupedConversations[stage]?.length"
            class="text-xs text-n-slate-10 p-2 rounded-md border border-dashed border-n-weak"
          >
            {{ t('CONTACTS_LAYOUT.SALES_PIPELINE.EMPTY_STAGE') }}
          </div>
        </div>
      </section>
    </div>
  </section>
</template>
