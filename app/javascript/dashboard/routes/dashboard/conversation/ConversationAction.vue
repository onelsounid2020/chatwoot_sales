<!-- eslint-disable vue/v-slot-style -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import ContactDetailsItem from './ContactDetailsItem.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import ConversationLabels from './labels/LabelBox.vue';
import { CONVERSATION_PRIORITY } from '../../../../shared/constants/messages';
import { CONVERSATION_EVENTS } from '../../../helper/AnalyticsHelper/events';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    ContactDetailsItem,
    MultiselectDropdown,
    ConversationLabels,
    NextButton,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  setup() {
    const { agentsList } = useAgentsList();
    return {
      agentsList,
    };
  },
  data() {
    return {
      dealValueInput: '',
      lostReasonInput: '',
      nextFollowUpInput: '',
      isSavingDealValue: false,
      isSavingLostReason: false,
      isSavingNextFollowUp: false,
      showResolveValidationErrors: false,
      priorityOptions: [
        {
          id: null,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.NONE'),
          icon: 'i-woot-priority-empty',
        },
        {
          id: CONVERSATION_PRIORITY.URGENT,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.URGENT'),
          icon: 'i-woot-priority-urgent',
        },
        {
          id: CONVERSATION_PRIORITY.HIGH,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.HIGH'),
          icon: 'i-woot-priority-high',
        },
        {
          id: CONVERSATION_PRIORITY.MEDIUM,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM'),
          icon: 'i-woot-priority-medium',
        },
        {
          id: CONVERSATION_PRIORITY.LOW,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.LOW'),
          icon: 'i-woot-priority-low',
        },
      ],
      dealStageOptions: [
        {
          id: 'incoming',
          name: this.$t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.INCOMING'),
        },
        {
          id: 'contacted',
          name: this.$t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.CONTACTED'),
        },
        {
          id: 'qualified',
          name: this.$t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.QUALIFIED'),
        },
        {
          id: 'proposal',
          name: this.$t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.PROPOSAL'),
        },
        {
          id: 'won',
          name: this.$t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.WON'),
        },
        {
          id: 'lost',
          name: this.$t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.LOST'),
        },
      ],
      dealCurrencyOptions: [
        {
          id: 'CLP',
          name: this.$t('CONVERSATION.SALES.DEAL_CURRENCY.OPTIONS.CLP'),
        },
        {
          id: 'USD',
          name: this.$t('CONVERSATION.SALES.DEAL_CURRENCY.OPTIONS.USD'),
        },
      ],
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUser: 'getCurrentUser',
      teams: 'teams/getTeams',
      inboxes: 'inboxes/getInboxes',
      currentAccount: 'getCurrentAccount',
      customAttributeDefinitions: 'attributes/getAttributes',
    }),
    currentInbox() {
      return (
        this.inboxes.find(inbox => inbox.id === this.currentChat?.inbox_id) ||
        {}
      );
    },
    resolveRuleConfig() {
      const globalRules =
        this.currentAccount?.settings?.conversation_resolve_rules || {};
      const inboxRules =
        this.currentInbox?.auto_assignment_config?.resolve_rules || {};

      const requiredConversationAttrs = [
        ...(globalRules.required_conversation_custom_attributes || []),
        ...(inboxRules.required_conversation_custom_attributes || []),
      ]
        .map(String)
        .filter(Boolean);

      const requiredContactAttrs = [
        ...(globalRules.required_contact_custom_attributes || []),
        ...(inboxRules.required_contact_custom_attributes || []),
      ]
        .map(String)
        .filter(Boolean);

      const allowedDealStages =
        inboxRules.allowed_deal_stages || globalRules.allowed_deal_stages || [];

      return {
        allowedDealStages: [...new Set(allowedDealStages.map(String))],
        requiredConversationAttrs: [...new Set(requiredConversationAttrs)],
        requiredContactAttrs: [...new Set(requiredContactAttrs)],
      };
    },
    hasResolveChecklist() {
      const {
        allowedDealStages,
        requiredConversationAttrs,
        requiredContactAttrs,
      } = this.resolveRuleConfig;
      return (
        allowedDealStages.length > 0 ||
        requiredConversationAttrs.length > 0 ||
        requiredContactAttrs.length > 0
      );
    },
    resolveChecklistItems() {
      const items = [];
      const {
        allowedDealStages,
        requiredConversationAttrs,
        requiredContactAttrs,
      } = this.resolveRuleConfig;

      if (allowedDealStages.length > 0) {
        const currentStage = this.currentChat?.deal_stage || 'incoming';
        items.push({
          key: 'allowed_deal_stages',
          fulfilled: allowedDealStages.includes(currentStage),
          label: this.$t('CONVERSATION.SALES.RESOLVE_CHECKLIST.STAGE_LABEL', {
            stages: allowedDealStages.join(', '),
          }),
        });
      }

      requiredConversationAttrs.forEach(attributeKey => {
        const value = this.currentChat?.custom_attributes?.[attributeKey];
        items.push({
          key: `conversation_${attributeKey}`,
          fulfilled: !this.isBlankValue(value),
          label: this.$t(
            'CONVERSATION.SALES.RESOLVE_CHECKLIST.CONVERSATION_ATTR_LABEL',
            {
              attribute: this.getAttributeDisplayName(
                attributeKey,
                'conversation_attribute'
              ),
            }
          ),
        });
      });

      requiredContactAttrs.forEach(attributeKey => {
        const value =
          this.currentChat?.meta?.sender?.custom_attributes?.[attributeKey];
        items.push({
          key: `contact_${attributeKey}`,
          fulfilled: !this.isBlankValue(value),
          label: this.$t(
            'CONVERSATION.SALES.RESOLVE_CHECKLIST.CONTACT_ATTR_LABEL',
            {
              attribute: this.getAttributeDisplayName(
                attributeKey,
                'contact_attribute'
              ),
            }
          ),
        });
      });

      if ((this.currentChat?.deal_stage || 'incoming') === 'lost') {
        const lostReason = this.currentChat?.lost_reason;
        items.push({
          key: 'lost_reason',
          fulfilled: !this.isBlankValue(lostReason),
          label: this.$t(
            'CONVERSATION.SALES.RESOLVE_CHECKLIST.LOST_REASON_LABEL'
          ),
        });
      }

      return items;
    },
    resolveChecklistReady() {
      return this.resolveChecklistItems.every(item => item.fulfilled);
    },
    hasResolveChecklistMissingItems() {
      return this.resolveChecklistItems.some(item => !item.fulfilled);
    },
    isDealStageMissingForResolve() {
      const stageRule = this.resolveChecklistItems.find(
        item => item.key === 'allowed_deal_stages'
      );
      return !!stageRule && !stageRule.fulfilled;
    },
    hasAnAssignedTeam() {
      return !!this.currentChat?.meta?.team;
    },
    teamsList() {
      if (this.hasAnAssignedTeam) {
        return [
          { id: 0, name: this.$t('TEAMS_SETTINGS.LIST.NONE') },
          ...this.teams,
        ];
      }
      return this.teams;
    },
    assignedAgent: {
      get() {
        return this.currentChat.meta.assignee;
      },
      set(agent) {
        const agentId = agent ? agent.id : null;
        this.$store.dispatch('setCurrentChatAssignee', {
          conversationId: this.currentChat.id,
          assignee: agent,
        });
        this.$store
          .dispatch('assignAgent', {
            conversationId: this.currentChat.id,
            agentId,
          })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_AGENT'));
          });
      },
    },
    assignedTeam: {
      get() {
        return this.currentChat.meta.team;
      },
      set(team) {
        const conversationId = this.currentChat.id;
        const teamId = team ? team.id : 0;
        this.$store.dispatch('setCurrentChatTeam', { team, conversationId });
        this.$store
          .dispatch('assignTeam', { conversationId, teamId })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_TEAM'));
          });
      },
    },
    assignedPriority: {
      get() {
        const selectedOption = this.priorityOptions.find(
          opt => opt.id === this.currentChat.priority
        );

        return selectedOption || this.priorityOptions[0];
      },
      set(priorityItem) {
        const conversationId = this.currentChat.id;
        const oldValue = this.currentChat?.priority;
        const priority = priorityItem ? priorityItem.id : null;

        this.$store.dispatch('setCurrentChatPriority', {
          priority,
          conversationId,
        });
        this.$store
          .dispatch('assignPriority', { conversationId, priority })
          .then(() => {
            useTrack(CONVERSATION_EVENTS.CHANGE_PRIORITY, {
              oldValue,
              newValue: priority,
              from: 'Conversation Sidebar',
            });
            useAlert(
              this.$t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
                priority: priorityItem.name,
                conversationId,
              })
            );
          });
      },
    },
    assignedDealStage: {
      get() {
        const currentStage = this.currentChat?.deal_stage || 'incoming';
        const selectedOption = this.dealStageOptions.find(
          opt => opt.id === currentStage
        );

        return selectedOption || this.dealStageOptions[0];
      },
      set(stageItem) {
        const selectedStage = stageItem?.id || 'incoming';
        this.$store
          .dispatch('updateConversationSalesInfo', {
            conversationId: this.currentChat.id,
            dealStage: selectedStage,
            dealValue: this.currentChat?.deal_value,
            dealCurrency: this.currentChat?.deal_currency || 'CLP',
            lostReason: this.currentChat?.lost_reason,
            nextFollowUpAt: this.currentChat?.next_follow_up_at,
            lastContactedAt: this.currentChat?.last_contacted_at,
          })
          .then(() => {
            useAlert(this.$t('CONVERSATION.SALES.DEAL_STAGE.SUCCESSFUL'));
          })
          .catch(() => {
            useAlert(this.$t('CONVERSATION.SALES.DEAL_STAGE.FAILED'));
          });
      },
    },
    assignedDealCurrency: {
      get() {
        const selectedCurrency = this.currentChat?.deal_currency || 'CLP';
        return (
          this.dealCurrencyOptions.find(opt => opt.id === selectedCurrency) ||
          this.dealCurrencyOptions[0]
        );
      },
      set(currencyItem) {
        const selectedCurrency = currencyItem?.id || 'CLP';
        this.$store
          .dispatch('updateConversationSalesInfo', {
            conversationId: this.currentChat.id,
            dealStage: this.currentChat?.deal_stage || 'incoming',
            dealValue: this.currentChat?.deal_value,
            dealCurrency: selectedCurrency,
            lostReason: this.currentChat?.lost_reason,
            nextFollowUpAt: this.currentChat?.next_follow_up_at,
            lastContactedAt: this.currentChat?.last_contacted_at,
          })
          .then(() => {
            useAlert(this.$t('CONVERSATION.SALES.DEAL_CURRENCY.SUCCESSFUL'));
          })
          .catch(() => {
            useAlert(this.$t('CONVERSATION.SALES.DEAL_CURRENCY.FAILED'));
          });
      },
    },
    showSelfAssign() {
      if (!this.assignedAgent) {
        return true;
      }
      if (this.assignedAgent.id !== this.currentUser.id) {
        return true;
      }
      return false;
    },
  },
  watch: {
    'currentChat.deal_value': {
      immediate: true,
      handler(newValue) {
        this.dealValueInput = newValue ?? '';
      },
    },
    'currentChat.lost_reason': {
      immediate: true,
      handler(newValue) {
        this.lostReasonInput = newValue || '';
      },
    },
    'currentChat.next_follow_up_at': {
      immediate: true,
      handler(newValue) {
        this.nextFollowUpInput = this.timestampToDatetimeLocal(newValue);
      },
    },
    resolveChecklistReady(isReady) {
      if (isReady) {
        this.showResolveValidationErrors = false;
      }
    },
  },
  mounted() {
    emitter.on(
      BUS_EVENTS.CONVERSATION_RESOLVE_REQUIREMENTS_BLOCKED,
      this.onResolveRequirementsBlocked
    );
  },
  unmounted() {
    emitter.off(
      BUS_EVENTS.CONVERSATION_RESOLVE_REQUIREMENTS_BLOCKED,
      this.onResolveRequirementsBlocked
    );
  },
  methods: {
    onResolveRequirementsBlocked(payload = {}) {
      this.showResolveValidationErrors = true;
      const firstMissingAttributeKey = payload?.missingAttributeKeys?.[0];
      if (firstMissingAttributeKey) {
        emitter.emit(
          BUS_EVENTS.FOCUS_CUSTOM_ATTRIBUTE,
          firstMissingAttributeKey
        );
      }
    },
    onSelfAssign() {
      const {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        avatar_url,
      } = this.currentUser;
      const selfAssign = {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        thumbnail: avatar_url,
      };
      this.assignedAgent = selfAssign;
    },
    onClickAssignAgent(selectedItem) {
      if (this.assignedAgent && this.assignedAgent.id === selectedItem.id) {
        this.assignedAgent = null;
      } else {
        this.assignedAgent = selectedItem;
      }
    },

    onClickAssignTeam(selectedItemTeam) {
      if (this.assignedTeam && this.assignedTeam.id === selectedItemTeam.id) {
        this.assignedTeam = null;
      } else {
        this.assignedTeam = selectedItemTeam;
      }
    },

    onClickAssignPriority(selectedPriorityItem) {
      const isSamePriority =
        this.assignedPriority &&
        this.assignedPriority.id === selectedPriorityItem.id;

      this.assignedPriority = isSamePriority ? null : selectedPriorityItem;
    },
    onClickAssignDealStage(selectedStageItem) {
      this.assignedDealStage = selectedStageItem;
    },
    onClickAssignDealCurrency(selectedCurrencyItem) {
      this.assignedDealCurrency = selectedCurrencyItem;
    },
    normalizeDealValueInput(value) {
      if (value === '' || value === null || value === undefined) return null;

      let raw = String(value).trim();
      if (!raw) return null;

      raw = raw.replace(/\s/g, '');

      if (raw.includes(',') && raw.includes('.')) {
        raw =
          raw.lastIndexOf(',') > raw.lastIndexOf('.')
            ? raw.replace(/\./g, '').replace(',', '.')
            : raw.replace(/,/g, '');
      } else if (raw.includes('.')) {
        if (/^\d{1,3}(\.\d{3})+$/.test(raw)) {
          raw = raw.replace(/\./g, '');
        }
      } else if (raw.includes(',')) {
        if (/^\d{1,3}(,\d{3})+$/.test(raw)) {
          raw = raw.replace(/,/g, '');
        } else {
          raw = raw.replace(',', '.');
        }
      }

      const numeric = Number(raw);
      return Number.isNaN(numeric) ? Number.NaN : numeric;
    },
    timestampToDatetimeLocal(timestamp) {
      if (!timestamp) return '';
      const date = new Date(Number(timestamp) * 1000);
      if (Number.isNaN(date.getTime())) return '';

      const pad = value => String(value).padStart(2, '0');
      const year = date.getFullYear();
      const month = pad(date.getMonth() + 1);
      const day = pad(date.getDate());
      const hours = pad(date.getHours());
      const minutes = pad(date.getMinutes());
      return `${year}-${month}-${day}T${hours}:${minutes}`;
    },
    datetimeLocalToTimestamp(value) {
      if (!value) return null;
      const date = new Date(value);
      if (Number.isNaN(date.getTime())) return Number.NaN;
      return Math.floor(date.getTime() / 1000);
    },
    onSaveDealValue() {
      if (this.isSavingDealValue) return;

      const normalizedValue = this.normalizeDealValueInput(this.dealValueInput);

      if (normalizedValue !== null && Number.isNaN(normalizedValue)) {
        useAlert(this.$t('CONVERSATION.SALES.DEAL_VALUE.FAILED'));
        return;
      }

      const currentValue = this.currentChat?.deal_value;
      const normalizedCurrentValue =
        currentValue === null || currentValue === undefined
          ? null
          : Number(currentValue);
      if (normalizedValue === normalizedCurrentValue) {
        return;
      }

      this.isSavingDealValue = true;
      this.$store
        .dispatch('updateConversationSalesInfo', {
          conversationId: this.currentChat.id,
          dealStage: this.currentChat?.deal_stage || 'incoming',
          dealValue: normalizedValue,
          dealCurrency: this.currentChat?.deal_currency || 'CLP',
          lostReason: this.currentChat?.lost_reason,
          nextFollowUpAt: this.currentChat?.next_follow_up_at,
          lastContactedAt: this.currentChat?.last_contacted_at,
        })
        .then(() => {
          this.dealValueInput =
            normalizedValue === null ? '' : String(normalizedValue);
        })
        .catch(() => {
          useAlert(this.$t('CONVERSATION.SALES.DEAL_VALUE.SAVE_FAILED'));
        })
        .finally(() => {
          this.isSavingDealValue = false;
        });
    },
    onSaveLostReason() {
      if (this.isSavingLostReason) return;

      const normalizedValue = this.lostReasonInput?.trim() || null;
      const currentValue = this.currentChat?.lost_reason?.trim() || null;
      if (normalizedValue === currentValue) return;

      this.isSavingLostReason = true;
      this.$store
        .dispatch('updateConversationSalesInfo', {
          conversationId: this.currentChat.id,
          dealStage: this.currentChat?.deal_stage || 'incoming',
          dealValue: this.currentChat?.deal_value,
          dealCurrency: this.currentChat?.deal_currency || 'CLP',
          lostReason: normalizedValue,
          nextFollowUpAt: this.currentChat?.next_follow_up_at,
          lastContactedAt: this.currentChat?.last_contacted_at,
        })
        .then(() => {
          this.lostReasonInput = normalizedValue || '';
        })
        .catch(() => {
          useAlert(this.$t('CONVERSATION.SALES.LOST_REASON.FAILED'));
        })
        .finally(() => {
          this.isSavingLostReason = false;
        });
    },
    clearNextFollowUp() {
      this.nextFollowUpInput = '';
      this.onSaveNextFollowUp();
    },
    setNextFollowUpFromNow(minutesFromNow) {
      if (this.isSavingNextFollowUp) return;

      const minutes = Number.parseInt(minutesFromNow, 10);
      if (Number.isNaN(minutes) || minutes <= 0) return;

      const followUpDate = new Date(Date.now() + minutes * 60 * 1000);
      const timestamp = Math.floor(followUpDate.getTime() / 1000);

      this.nextFollowUpInput = this.timestampToDatetimeLocal(timestamp);
      this.onSaveNextFollowUp();
    },
    onSaveNextFollowUp() {
      if (this.isSavingNextFollowUp) return;

      const normalizedValue = this.datetimeLocalToTimestamp(
        this.nextFollowUpInput
      );
      if (normalizedValue !== null && Number.isNaN(normalizedValue)) {
        useAlert(this.$t('CONVERSATION.SALES.NEXT_FOLLOW_UP.FAILED'));
        return;
      }

      const currentValue = this.currentChat?.next_follow_up_at || null;
      if (normalizedValue === currentValue) return;

      this.isSavingNextFollowUp = true;
      this.$store
        .dispatch('updateConversationSalesInfo', {
          conversationId: this.currentChat.id,
          dealStage: this.currentChat?.deal_stage || 'incoming',
          dealValue: this.currentChat?.deal_value,
          dealCurrency: this.currentChat?.deal_currency || 'CLP',
          lostReason: this.currentChat?.lost_reason,
          nextFollowUpAt: normalizedValue,
          lastContactedAt: this.currentChat?.last_contacted_at,
        })
        .then(() => {
          this.nextFollowUpInput =
            this.timestampToDatetimeLocal(normalizedValue);
          useAlert(this.$t('CONVERSATION.SALES.NEXT_FOLLOW_UP.SUCCESSFUL'));
        })
        .catch(() => {
          useAlert(this.$t('CONVERSATION.SALES.NEXT_FOLLOW_UP.SAVE_FAILED'));
        })
        .finally(() => {
          this.isSavingNextFollowUp = false;
        });
    },
    isBlankValue(value) {
      if (value === null || value === undefined) return true;
      if (typeof value === 'string') return !value.trim();
      if (Array.isArray(value)) return value.length === 0;
      return false;
    },
    getAttributeDisplayName(attributeKey, attributeModel) {
      const attribute = this.customAttributeDefinitions.find(
        item =>
          item.attribute_key === attributeKey &&
          item.attribute_model === attributeModel
      );
      return attribute?.attribute_display_name || attributeKey;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <section class="rounded-xl border border-n-weak bg-n-solid-1 p-2">
      <p class="px-2 pb-1 text-[11px] uppercase tracking-wide text-n-slate-10">
        {{ $t('CONVERSATION.SALES.PANEL_SECTIONS.EXECUTION') }}
      </p>
      <div>
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL')"
        >
          <template #button>
            <NextButton
              v-if="showSelfAssign"
              link
              xs
              icon="i-lucide-arrow-right"
              class="!gap-1"
              :label="$t('CONVERSATION_SIDEBAR.SELF_ASSIGN')"
              @click="onSelfAssign"
            />
          </template>
        </ContactDetailsItem>
        <MultiselectDropdown
          :options="agentsList"
          :selected-item="assignedAgent"
          :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.AGENT')"
          :multiselector-placeholder="
            $t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')
          "
          :no-search-result="
            $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
          "
          :input-placeholder="
            $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
          "
          @select="onClickAssignAgent"
        />
      </div>
      <div>
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION_SIDEBAR.TEAM_LABEL')"
        />
        <MultiselectDropdown
          :options="teamsList"
          :selected-item="assignedTeam"
          :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.TEAM')"
          :multiselector-placeholder="
            $t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')
          "
          :no-search-result="
            $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.TEAM')
          "
          :input-placeholder="
            $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.TEAM')
          "
          @select="onClickAssignTeam"
        />
      </div>
      <div>
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION.PRIORITY.TITLE')"
        />
        <MultiselectDropdown
          :options="priorityOptions"
          :selected-item="assignedPriority"
          :multiselector-title="$t('CONVERSATION.PRIORITY.TITLE')"
          :multiselector-placeholder="
            $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SELECT_PLACEHOLDER')
          "
          :no-search-result="
            $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.NO_RESULTS')
          "
          :input-placeholder="
            $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.INPUT_PLACEHOLDER')
          "
          @select="onClickAssignPriority"
        />
      </div>
    </section>

    <section class="rounded-xl border border-n-weak bg-n-solid-1 p-2">
      <p class="px-2 pb-1 text-[11px] uppercase tracking-wide text-n-slate-10">
        {{ $t('CONVERSATION.SALES.PANEL_SECTIONS.PIPELINE') }}
      </p>
      <div
        class="rounded-lg"
        :class="
          showResolveValidationErrors && isDealStageMissingForResolve
            ? 'p-2 border border-n-ruby-6 bg-n-ruby-3/40'
            : ''
        "
      >
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION.SALES.DEAL_STAGE.TITLE')"
        />
        <MultiselectDropdown
          :options="dealStageOptions"
          :selected-item="assignedDealStage"
          :multiselector-title="$t('CONVERSATION.SALES.DEAL_STAGE.TITLE')"
          :multiselector-placeholder="
            $t('CONVERSATION.SALES.DEAL_STAGE.SELECT_PLACEHOLDER')
          "
          :no-search-result="$t('CONVERSATION.SALES.DEAL_STAGE.NO_RESULTS')"
          :input-placeholder="
            $t('CONVERSATION.SALES.DEAL_STAGE.INPUT_PLACEHOLDER')
          "
          @select="onClickAssignDealStage"
        />
      </div>
      <div class="pb-2">
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION.SALES.DEAL_CURRENCY.TITLE')"
        />
        <MultiselectDropdown
          :options="dealCurrencyOptions"
          :selected-item="assignedDealCurrency"
          :multiselector-title="$t('CONVERSATION.SALES.DEAL_CURRENCY.TITLE')"
          :multiselector-placeholder="
            $t('CONVERSATION.SALES.DEAL_CURRENCY.SELECT_PLACEHOLDER')
          "
          :no-search-result="$t('CONVERSATION.SALES.DEAL_CURRENCY.NO_RESULTS')"
          :input-placeholder="
            $t('CONVERSATION.SALES.DEAL_CURRENCY.INPUT_PLACEHOLDER')
          "
          @select="onClickAssignDealCurrency"
        />
      </div>
      <div class="pb-2">
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION.SALES.DEAL_VALUE.TITLE')"
        />
        <div class="flex items-end gap-2">
          <woot-input
            v-model="dealValueInput"
            type="text"
            inputmode="decimal"
            class="w-full !mb-0"
            :placeholder="$t('CONVERSATION.SALES.DEAL_VALUE.PLACEHOLDER')"
            @blur="onSaveDealValue"
            @keydown.enter.prevent="onSaveDealValue"
          />
        </div>
      </div>
      <div class="pb-2">
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION.SALES.NEXT_FOLLOW_UP.TITLE')"
        >
          <template #button>
            <NextButton
              v-if="nextFollowUpInput"
              link
              xs
              icon="i-lucide-x"
              class="!gap-1"
              :label="$t('CONVERSATION.SALES.NEXT_FOLLOW_UP.CLEAR')"
              @click="clearNextFollowUp"
            />
          </template>
        </ContactDetailsItem>
        <woot-input
          v-model="nextFollowUpInput"
          type="datetime-local"
          class="w-full !mb-0"
          :placeholder="$t('CONVERSATION.SALES.NEXT_FOLLOW_UP.PLACEHOLDER')"
          @blur="onSaveNextFollowUp"
          @keydown.enter.prevent="onSaveNextFollowUp"
        />
        <div class="mt-2 flex items-center gap-2">
          <button
            type="button"
            class="px-2 py-1 rounded-md text-xs border border-n-weak text-n-slate-12 hover:bg-n-alpha-2"
            @click="setNextFollowUpFromNow(30)"
          >
            {{ $t('CONVERSATION.SALES.NEXT_FOLLOW_UP.QUICK.MINUTES_30') }}
          </button>
          <button
            type="button"
            class="px-2 py-1 rounded-md text-xs border border-n-weak text-n-slate-12 hover:bg-n-alpha-2"
            @click="setNextFollowUpFromNow(60)"
          >
            {{ $t('CONVERSATION.SALES.NEXT_FOLLOW_UP.QUICK.HOUR_1') }}
          </button>
          <button
            type="button"
            class="px-2 py-1 rounded-md text-xs border border-n-weak text-n-slate-12 hover:bg-n-alpha-2"
            @click="setNextFollowUpFromNow(1440)"
          >
            {{ $t('CONVERSATION.SALES.NEXT_FOLLOW_UP.QUICK.HOURS_24') }}
          </button>
        </div>
      </div>
      <div
        v-if="(currentChat?.deal_stage || 'incoming') === 'lost'"
        class="pb-2"
      >
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION.SALES.LOST_REASON.TITLE')"
        />
        <woot-input
          v-model="lostReasonInput"
          type="text"
          class="w-full !mb-0"
          :placeholder="$t('CONVERSATION.SALES.LOST_REASON.PLACEHOLDER')"
          @blur="onSaveLostReason"
          @keydown.enter.prevent="onSaveLostReason"
        />
      </div>
    </section>

    <section
      v-if="hasResolveChecklist"
      class="rounded-xl border border-n-weak bg-n-solid-1 p-2"
    >
      <p class="px-2 pb-1 text-[11px] uppercase tracking-wide text-n-slate-10">
        {{ $t('CONVERSATION.SALES.PANEL_SECTIONS.CLOSURE') }}
      </p>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION.SALES.RESOLVE_CHECKLIST.TITLE')"
      />
      <div
        class="p-2 rounded-lg border"
        :class="
          showResolveValidationErrors && hasResolveChecklistMissingItems
            ? 'border-n-ruby-6 bg-n-ruby-3'
            : resolveChecklistReady
              ? 'border-n-teal-5 bg-n-teal-3'
              : 'border-n-amber-5 bg-n-amber-3'
        "
      >
        <p
          class="text-xs mb-2"
          :class="
            showResolveValidationErrors && hasResolveChecklistMissingItems
              ? 'text-n-ruby-11'
              : resolveChecklistReady
                ? 'text-n-teal-12'
                : 'text-n-amber-12'
          "
        >
          {{
            showResolveValidationErrors && hasResolveChecklistMissingItems
              ? $t('CONVERSATION.SALES.RESOLVE_CHECKLIST.BLOCKED_ALERT')
              : resolveChecklistReady
                ? $t('CONVERSATION.SALES.RESOLVE_CHECKLIST.READY')
                : $t('CONVERSATION.SALES.RESOLVE_CHECKLIST.BLOCKED')
          }}
        </p>
        <ul class="flex flex-col gap-1">
          <li
            v-for="item in resolveChecklistItems"
            :key="item.key"
            class="flex items-center gap-2 text-xs"
            :class="
              item.fulfilled
                ? 'text-n-teal-12'
                : showResolveValidationErrors
                  ? 'text-n-ruby-11'
                  : 'text-n-amber-12'
            "
          >
            <i
              :class="
                item.fulfilled
                  ? 'i-lucide-circle-check-big'
                  : showResolveValidationErrors
                    ? 'i-lucide-circle-x'
                    : 'i-lucide-circle-alert'
              "
            />
            <span>{{ item.label }}</span>
          </li>
        </ul>
      </div>
    </section>

    <section class="rounded-xl border border-n-weak bg-n-solid-1 p-2">
      <p class="px-2 pb-1 text-[11px] uppercase tracking-wide text-n-slate-10">
        {{ $t('CONVERSATION.SALES.PANEL_SECTIONS.CONTEXT') }}
      </p>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS')"
      />
      <ConversationLabels :conversation-id="conversationId" />
    </section>
  </div>
</template>
