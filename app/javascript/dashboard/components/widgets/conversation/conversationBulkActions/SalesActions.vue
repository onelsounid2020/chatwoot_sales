<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['apply', 'close']);
const { t } = useI18n();

const actions = ref([
  {
    icon: 'i-lucide-user-check',
    key: 'set_stage_contacted',
  },
  {
    icon: 'i-lucide-file-text',
    key: 'set_stage_proposal',
  },
  {
    icon: 'i-lucide-clock-3',
    key: 'set_follow_up_1h',
  },
  {
    icon: 'i-lucide-calendar-clock',
    key: 'set_follow_up_24h',
  },
]);

const onClose = () => emit('close');

const actionLabel = key => {
  const labelsMap = {
    set_stage_contacted: t('BULK_ACTION.SALES.SET_STAGE_CONTACTED'),
    set_stage_proposal: t('BULK_ACTION.SALES.SET_STAGE_PROPOSAL'),
    set_follow_up_1h: t('BULK_ACTION.SALES.SET_FOLLOW_UP_1H'),
    set_follow_up_24h: t('BULK_ACTION.SALES.SET_FOLLOW_UP_24H'),
  };
  return labelsMap[key] || '';
};
</script>

<template>
  <div
    v-on-clickaway="onClose"
    class="absolute z-20 w-auto origin-top-right border border-solid rounded-lg shadow-md ltr:right-2 rtl:left-2 top-12 bg-n-alpha-3 backdrop-blur-[100px] border-n-weak"
  >
    <div
      class="right-[var(--triangle-position)] block z-10 absolute text-left -top-3"
    >
      <svg height="12" viewBox="0 0 24 12" width="24">
        <path
          d="M20 12l-8-8-12 12"
          fill-rule="evenodd"
          stroke-width="1px"
          class="fill-n-alpha-3 backdrop-blur-[100px] stroke-n-weak"
        />
      </svg>
    </div>
    <div class="p-2.5 flex gap-1 items-center justify-between">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('BULK_ACTION.SALES.TITLE') }}
      </span>
      <Button ghost xs slate icon="i-lucide-x" @click="onClose" />
    </div>
    <div class="px-2.5 pt-0 pb-2.5">
      <WootDropdownMenu class="m-0 list-none">
        <WootDropdownItem v-for="action in actions" :key="action.key">
          <Button
            ghost
            sm
            slate
            class="!w-full !justify-start"
            :icon="action.icon"
            :label="actionLabel(action.key)"
            @click="emit('apply', action.key)"
          />
        </WootDropdownItem>
      </WootDropdownMenu>
    </div>
  </div>
</template>
