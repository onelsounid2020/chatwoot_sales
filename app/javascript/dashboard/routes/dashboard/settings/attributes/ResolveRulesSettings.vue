<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'vuex';
import MultiSelect from 'dashboard/components-next/filter/inputs/MultiSelect.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';

const props = defineProps({
  conversationAttributes: {
    type: Array,
    default: () => [],
  },
  contactAttributes: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();
const store = useStore();

const isSubmitting = ref(false);
const isInboxSubmitting = ref(false);
const allowedDealStages = ref([]);
const requiredConversationAttributes = ref([]);
const requiredContactAttributes = ref([]);
const forecastWeights = ref({
  incoming: 10,
  contacted: 25,
  qualified: 50,
  proposal: 75,
  won: 100,
  lost: 0,
});

const dealStageOptions = computed(() => [
  { id: 'incoming', name: t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.INCOMING') },
  {
    id: 'contacted',
    name: t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.CONTACTED'),
  },
  {
    id: 'qualified',
    name: t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.QUALIFIED'),
  },
  { id: 'proposal', name: t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.PROPOSAL') },
  { id: 'won', name: t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.WON') },
  { id: 'lost', name: t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.LOST') },
]);

const conversationAttributeOptions = computed(() =>
  props.conversationAttributes.map(attribute => ({
    id: attribute.attribute_key,
    name: attribute.attribute_display_name,
  }))
);

const contactAttributeOptions = computed(() =>
  props.contactAttributes.map(attribute => ({
    id: attribute.attribute_key,
    name: attribute.attribute_display_name,
  }))
);

const mapKeysToOptions = (keys, options) => {
  const normalizedKeys = (keys || []).map(String);
  return options.filter(option => normalizedKeys.includes(option.id));
};

const normalizedPercent = (value, fallback) => {
  const numberValue = Number(value);
  if (Number.isNaN(numberValue)) return fallback;
  return numberValue;
};

const defaultForecastWeights = {
  incoming: 10,
  contacted: 25,
  qualified: 50,
  proposal: 75,
  won: 100,
  lost: 0,
};

const normalizeForecastWeights = (configuredWeights, fallbackWeights) => ({
  incoming: normalizedPercent(
    Number(configuredWeights.incoming) * 100,
    fallbackWeights.incoming
  ),
  contacted: normalizedPercent(
    Number(configuredWeights.contacted) * 100,
    fallbackWeights.contacted
  ),
  qualified: normalizedPercent(
    Number(configuredWeights.qualified) * 100,
    fallbackWeights.qualified
  ),
  proposal: normalizedPercent(
    Number(configuredWeights.proposal) * 100,
    fallbackWeights.proposal
  ),
  won: normalizedPercent(
    Number(configuredWeights.won) * 100,
    fallbackWeights.won
  ),
  lost: normalizedPercent(
    Number(configuredWeights.lost) * 100,
    fallbackWeights.lost
  ),
});

watch(
  [
    currentAccount,
    dealStageOptions,
    conversationAttributeOptions,
    contactAttributeOptions,
  ],
  () => {
    const rules =
      currentAccount.value?.settings?.conversation_resolve_rules || {};
    allowedDealStages.value = mapKeysToOptions(
      rules.allowed_deal_stages,
      dealStageOptions.value
    );
    requiredConversationAttributes.value = mapKeysToOptions(
      rules.required_conversation_custom_attributes,
      conversationAttributeOptions.value
    );
    requiredContactAttributes.value = mapKeysToOptions(
      rules.required_contact_custom_attributes,
      contactAttributeOptions.value
    );

    const configuredWeights =
      currentAccount.value?.settings?.sales_forecast_stage_weights || {};
    forecastWeights.value = normalizeForecastWeights(
      configuredWeights,
      defaultForecastWeights
    );
  },
  { immediate: true, deep: true }
);

const hasInvalidForecastWeights = computed(() =>
  Object.values(forecastWeights.value).some(weight => {
    const weightNumber = Number(weight);
    return Number.isNaN(weightNumber) || weightNumber < 0 || weightNumber > 100;
  })
);

const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);
const inboxOptions = computed(() =>
  inboxes.value.map(inbox => ({
    id: inbox.id,
    name: inbox.name,
  }))
);
const selectedInboxId = ref(null);
const inboxForecastWeights = ref({ ...defaultForecastWeights });

watch(
  [selectedInboxId, inboxes, forecastWeights],
  () => {
    const selectedInbox = inboxes.value.find(
      inbox => inbox.id === selectedInboxId.value
    );
    if (!selectedInbox) {
      inboxForecastWeights.value = { ...forecastWeights.value };
      return;
    }

    const inboxWeights =
      selectedInbox.auto_assignment_config?.resolve_rules
        ?.sales_forecast_stage_weights;
    inboxForecastWeights.value = normalizeForecastWeights(
      inboxWeights || {},
      forecastWeights.value
    );
  },
  { immediate: true, deep: true }
);

const hasInvalidInboxForecastWeights = computed(() =>
  Object.values(inboxForecastWeights.value).some(weight => {
    const weightNumber = Number(weight);
    return Number.isNaN(weightNumber) || weightNumber < 0 || weightNumber > 100;
  })
);

const saveRules = async () => {
  if (hasInvalidForecastWeights.value) {
    useAlert(t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.INVALID'));
    return;
  }

  const payload = {
    conversation_resolve_rules: {
      allowed_deal_stages: allowedDealStages.value.map(option => option.id),
      required_conversation_custom_attributes:
        requiredConversationAttributes.value.map(option => option.id),
      required_contact_custom_attributes: requiredContactAttributes.value.map(
        option => option.id
      ),
    },
    sales_forecast_stage_weights: {
      incoming: Number(forecastWeights.value.incoming) / 100,
      contacted: Number(forecastWeights.value.contacted) / 100,
      qualified: Number(forecastWeights.value.qualified) / 100,
      proposal: Number(forecastWeights.value.proposal) / 100,
      won: Number(forecastWeights.value.won) / 100,
      lost: Number(forecastWeights.value.lost) / 100,
    },
  };

  try {
    isSubmitting.value = true;
    await updateAccount(payload, { silent: true });
    useAlert(t('ATTRIBUTES_MGMT.RESOLVE_RULES.API.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('ATTRIBUTES_MGMT.RESOLVE_RULES.API.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};

const saveInboxForecastOverride = async () => {
  if (!selectedInboxId.value) {
    useAlert(t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.INBOX_REQUIRED'));
    return;
  }
  if (hasInvalidInboxForecastWeights.value) {
    useAlert(t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.INVALID'));
    return;
  }

  const selectedInbox = inboxes.value.find(
    inbox => inbox.id === selectedInboxId.value
  );
  if (!selectedInbox) {
    useAlert(t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.INBOX_REQUIRED'));
    return;
  }

  const existingAutoAssignmentConfig =
    selectedInbox.auto_assignment_config || {};
  const existingResolveRules = existingAutoAssignmentConfig.resolve_rules || {};

  const payload = {
    id: selectedInbox.id,
    formData: false,
    auto_assignment_config: {
      ...existingAutoAssignmentConfig,
      resolve_rules: {
        ...existingResolveRules,
        sales_forecast_stage_weights: {
          incoming: Number(inboxForecastWeights.value.incoming) / 100,
          contacted: Number(inboxForecastWeights.value.contacted) / 100,
          qualified: Number(inboxForecastWeights.value.qualified) / 100,
          proposal: Number(inboxForecastWeights.value.proposal) / 100,
          won: Number(inboxForecastWeights.value.won) / 100,
          lost: Number(inboxForecastWeights.value.lost) / 100,
        },
      },
    },
  };

  try {
    isInboxSubmitting.value = true;
    await store.dispatch('inboxes/updateInbox', payload);
    useAlert(t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.API.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.API.ERROR_MESSAGE'));
  } finally {
    isInboxSubmitting.value = false;
  }
};

store.dispatch('inboxes/get');
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
  >
    <div class="px-5 py-4">
      <h3 class="text-heading-2 text-n-slate-12">
        {{ t('ATTRIBUTES_MGMT.RESOLVE_RULES.TITLE') }}
      </h3>
      <p class="mb-0 mt-1 text-body-para text-n-slate-11">
        {{ t('ATTRIBUTES_MGMT.RESOLVE_RULES.DESCRIPTION') }}
      </p>
    </div>

    <div class="px-5 py-4 grid gap-5">
      <div class="grid gap-2">
        <p class="mb-0 text-sm text-n-slate-12">
          {{ t('ATTRIBUTES_MGMT.RESOLVE_RULES.ALLOWED_STAGES_LABEL') }}
        </p>
        <MultiSelect
          v-model="allowedDealStages"
          :options="dealStageOptions"
          dropdown-max-height="max-h-64"
        />
      </div>

      <div class="grid gap-2">
        <p class="mb-0 text-sm text-n-slate-12">
          {{
            t(
              'ATTRIBUTES_MGMT.RESOLVE_RULES.REQUIRED_CONVERSATION_ATTRIBUTES_LABEL'
            )
          }}
        </p>
        <MultiSelect
          v-model="requiredConversationAttributes"
          :options="conversationAttributeOptions"
          dropdown-max-height="max-h-64"
        />
      </div>

      <div class="grid gap-2">
        <p class="mb-0 text-sm text-n-slate-12">
          {{
            t('ATTRIBUTES_MGMT.RESOLVE_RULES.REQUIRED_CONTACT_ATTRIBUTES_LABEL')
          }}
        </p>
        <MultiSelect
          v-model="requiredContactAttributes"
          :options="contactAttributeOptions"
          dropdown-max-height="max-h-64"
        />
      </div>

      <div class="grid gap-3">
        <p class="mb-0 text-sm text-n-slate-12">
          {{ t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.TITLE') }}
        </p>
        <p class="mb-0 text-xs text-n-slate-11">
          {{ t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.HINT') }}
        </p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <woot-input
            v-model.number="forecastWeights.incoming"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.INCOMING')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="forecastWeights.contacted"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.CONTACTED')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="forecastWeights.qualified"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.QUALIFIED')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="forecastWeights.proposal"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.PROPOSAL')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="forecastWeights.won"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.WON')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="forecastWeights.lost"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.LOST')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
        </div>
      </div>

      <div class="flex">
        <NextButton
          blue
          :is-loading="isSubmitting"
          :label="t('ATTRIBUTES_MGMT.RESOLVE_RULES.SAVE_BUTTON')"
          @click="saveRules"
        />
      </div>

      <div class="grid gap-3 border-t border-n-weak pt-4">
        <p class="mb-0 text-sm text-n-slate-12">
          {{ t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.INBOX_TITLE') }}
        </p>
        <p class="mb-0 text-xs text-n-slate-11">
          {{ t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.INBOX_HINT') }}
        </p>

        <MultiselectDropdown
          :options="inboxOptions"
          :selected-item="
            inboxOptions.find(option => option.id === selectedInboxId) || null
          "
          :multiselector-title="
            t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.INBOX_LABEL')
          "
          :multiselector-placeholder="
            t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.INBOX_PLACEHOLDER')
          "
          :no-search-result="
            t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.NO_RESULTS')
          "
          :input-placeholder="
            t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.SEARCH_PLACEHOLDER')
          "
          @select="option => (selectedInboxId = option?.id || null)"
        />

        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <woot-input
            v-model.number="inboxForecastWeights.incoming"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.INCOMING')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="inboxForecastWeights.contacted"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.CONTACTED')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="inboxForecastWeights.qualified"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.QUALIFIED')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="inboxForecastWeights.proposal"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.PROPOSAL')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="inboxForecastWeights.won"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.WON')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
          <woot-input
            v-model.number="inboxForecastWeights.lost"
            type="number"
            min="0"
            max="100"
            :label="t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.LOST')"
            :placeholder="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.PLACEHOLDER')
            "
          />
        </div>

        <div class="flex">
          <NextButton
            blue
            :is-loading="isInboxSubmitting"
            :label="
              t('ATTRIBUTES_MGMT.RESOLVE_RULES.FORECAST.SAVE_INBOX_BUTTON')
            "
            @click="saveInboxForecastOverride"
          />
        </div>
      </div>
    </div>
  </div>
</template>
