<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import Avatar from 'next/avatar/Avatar.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import wootConstants from 'dashboard/constants/globals';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { useInbox } from 'dashboard/composables/useInbox';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox } = useInbox();

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_unattended: 'unattended',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasMultipleInboxes = computed(
  () => store.getters['inboxes/getInboxes'].length > 1
);

const hasSlaPolicyId = computed(() => props.chat?.sla_policy_id);

const dealStageLabel = computed(() => {
  const stage = currentChat.value?.deal_stage || 'incoming';
  if (stage === 'incoming') {
    return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.INCOMING');
  }
  if (stage === 'contacted') {
    return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.CONTACTED');
  }
  if (stage === 'qualified') {
    return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.QUALIFIED');
  }
  if (stage === 'proposal') {
    return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.PROPOSAL');
  }
  if (stage === 'won') {
    return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.WON');
  }
  if (stage === 'lost') {
    return t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.LOST');
  }
  return stage;
});

const dealValueLabel = computed(() => {
  const rawValue = currentChat.value?.deal_value;
  if (rawValue === null || rawValue === undefined || rawValue === '') {
    return t('CONVERSATION.HEADER.OPPORTUNITY.NO_VALUE');
  }

  const numericValue = Number(rawValue);
  if (Number.isNaN(numericValue)) {
    return t('CONVERSATION.HEADER.OPPORTUNITY.NO_VALUE');
  }

  const currency = currentChat.value?.deal_currency || 'CLP';
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency,
    maximumFractionDigits: 2,
  }).format(numericValue);
});

const nextFollowUpLabel = computed(() => {
  const timestamp = Number(currentChat.value?.next_follow_up_at || 0);
  if (!timestamp) return t('CONVERSATION.HEADER.OPPORTUNITY.NO_FOLLOW_UP');

  const date = new Date(timestamp * 1000);
  if (Number.isNaN(date.getTime())) {
    return t('CONVERSATION.HEADER.OPPORTUNITY.NO_FOLLOW_UP');
  }

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
});

const followUpStatus = computed(() => {
  const nextFollowUpAt = Number(currentChat.value?.next_follow_up_at || 0);
  if (!nextFollowUpAt) return 'missing';

  const lastContactedAt = Number(currentChat.value?.last_contacted_at || 0);
  if (lastContactedAt && lastContactedAt >= nextFollowUpAt) {
    return 'completed';
  }

  const now = Math.floor(Date.now() / 1000);
  const diffInSeconds = nextFollowUpAt - now;

  if (diffInSeconds < 0) return 'overdue';
  if (diffInSeconds <= 24 * 60 * 60) return 'today';
  return 'scheduled';
});

const followUpStatusLabel = computed(() => {
  const status = followUpStatus.value;
  if (status === 'overdue') {
    return t('CONVERSATION.HEADER.OPPORTUNITY.STATUS.OVERDUE');
  }
  if (status === 'today') {
    return t('CONVERSATION.HEADER.OPPORTUNITY.STATUS.TODAY');
  }
  if (status === 'missing') {
    return t('CONVERSATION.HEADER.OPPORTUNITY.STATUS.MISSING');
  }
  if (status === 'completed') {
    return t('CONVERSATION.HEADER.OPPORTUNITY.STATUS.COMPLETED');
  }
  return t('CONVERSATION.HEADER.OPPORTUNITY.STATUS.SCHEDULED');
});

const followUpStatusClass = computed(() => {
  const status = followUpStatus.value;
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
});

const updateSalesInfo = async updates => {
  try {
    await store.dispatch('updateConversationSalesInfo', {
      conversationId: currentChat.value.id,
      dealStage:
        updates.dealStage ?? (currentChat.value?.deal_stage || 'incoming'),
      dealValue: updates.dealValue ?? currentChat.value?.deal_value,
      dealCurrency:
        updates.dealCurrency ?? (currentChat.value?.deal_currency || 'CLP'),
      lostReason: updates.lostReason ?? currentChat.value?.lost_reason,
      nextFollowUpAt:
        updates.nextFollowUpAt !== undefined
          ? updates.nextFollowUpAt
          : currentChat.value?.next_follow_up_at,
      lastContactedAt:
        updates.lastContactedAt !== undefined
          ? updates.lastContactedAt
          : currentChat.value?.last_contacted_at,
    });
  } catch (error) {
    useAlert(t('CONVERSATION.HEADER.OPPORTUNITY.SAVE_FAILED'));
  }
};

const setStage = stage => updateSalesInfo({ dealStage: stage });

const setFollowUpFromNow = minutes => {
  const timestamp = Math.floor(Date.now() / 1000) + minutes * 60;
  return updateSalesInfo({ nextFollowUpAt: timestamp });
};

const markContactedNow = () => {
  const now = Math.floor(Date.now() / 1000);
  return updateSalesInfo({ lastContactedAt: now });
};
</script>

<template>
  <div
    ref="conversationHeader"
    class="flex flex-col gap-2 flex-1 w-full min-w-0 px-3 pt-2 pb-2 border-b border-n-weak"
  >
    <div class="flex items-center justify-between w-full max-w-full min-w-0">
      <div class="flex items-center justify-start max-w-full min-w-0 flex-1">
        <BackButton
          v-if="showBackButton"
          :back-url="backButtonUrl"
          class="ltr:mr-2 rtl:ml-2"
        />
        <Avatar
          :name="currentContact.name"
          :src="currentContact.thumbnail"
          :size="32"
          :status="currentContact.availability_status"
          hide-offline-status
          rounded-full
        />
        <div
          class="flex flex-col items-start min-w-0 ml-2 overflow-hidden rtl:ml-0 rtl:mr-2"
        >
          <div class="flex flex-row items-center max-w-full gap-1 p-0 m-0">
            <span
              class="text-sm font-medium truncate leading-tight text-n-slate-12"
            >
              {{ currentContact.name }}
            </span>
            <fluent-icon
              v-if="!isHMACVerified"
              v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
              size="14"
              class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
              icon="warning"
            />
          </div>

          <div
            class="flex items-center gap-2 overflow-hidden text-xs conversation--header--actions text-ellipsis whitespace-nowrap"
          >
            <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
            <span v-if="isSnoozed" class="font-medium text-n-amber-10">
              {{ snoozedDisplayText }}
            </span>
          </div>
        </div>
      </div>
      <div
        class="flex flex-row items-center justify-end flex-shrink-0 gap-2 header-actions-wrap"
      >
        <SLACardLabel
          v-if="hasSlaPolicyId"
          :chat="chat"
          show-extended-info
          :parent-width="width"
          class="hidden md:flex"
        />
        <MoreActions :conversation-id="currentChat.id" />
      </div>
    </div>

    <div
      class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-2 py-2 flex flex-wrap items-center gap-2"
    >
      <span
        class="text-[11px] px-2 py-1 rounded-md border border-n-weak bg-n-alpha-2 text-n-slate-12 font-medium flex items-center gap-1"
      >
        <span class="text-n-slate-10">{{
          $t('CONVERSATION.HEADER.OPPORTUNITY.STAGE')
        }}</span>
        <span>{{ dealStageLabel }}</span>
      </span>
      <span
        class="text-[11px] px-2 py-1 rounded-md border border-n-weak bg-n-alpha-2 text-n-slate-12 font-medium flex items-center gap-1"
      >
        <span class="text-n-slate-10">{{
          $t('CONVERSATION.HEADER.OPPORTUNITY.VALUE')
        }}</span>
        <span>{{ dealValueLabel }}</span>
      </span>
      <span
        class="text-[11px] px-2 py-1 rounded-md border border-n-weak bg-n-alpha-2 text-n-slate-12 font-medium flex items-center gap-1"
      >
        <span class="text-n-slate-10">{{
          $t('CONVERSATION.HEADER.OPPORTUNITY.NEXT_FOLLOW_UP')
        }}</span>
        <span>{{ nextFollowUpLabel }}</span>
      </span>
      <span
        class="text-[11px] px-2 py-1 rounded-md border font-medium"
        :class="followUpStatusClass"
      >
        {{ followUpStatusLabel }}
      </span>

      <div class="flex items-center gap-1 ml-auto">
        <NextButton
          xs
          slate
          faded
          :label="$t('CONVERSATION.HEADER.OPPORTUNITY.ACTIONS.STAGE_CONTACTED')"
          @click="setStage('contacted')"
        />
        <NextButton
          xs
          slate
          faded
          :label="$t('CONVERSATION.HEADER.OPPORTUNITY.ACTIONS.STAGE_PROPOSAL')"
          @click="setStage('proposal')"
        />
        <NextButton
          xs
          slate
          faded
          :label="$t('CONVERSATION.HEADER.OPPORTUNITY.ACTIONS.FOLLOW_UP_1H')"
          @click="setFollowUpFromNow(60)"
        />
        <NextButton
          xs
          slate
          faded
          :label="$t('CONVERSATION.HEADER.OPPORTUNITY.ACTIONS.FOLLOW_UP_24H')"
          @click="setFollowUpFromNow(1440)"
        />
        <NextButton
          xs
          slate
          faded
          :label="$t('CONVERSATION.HEADER.OPPORTUNITY.ACTIONS.CONTACTED_NOW')"
          @click="markContactedNow"
        />
      </div>
    </div>
  </div>
</template>
