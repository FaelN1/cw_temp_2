<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

const props = defineProps({
  items: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['close', 'confirm']);
const { t } = useI18n();
const store = useStore();

const selectedItems = ref([]);
const selectedStage = ref('');

const stages = computed(() => {
  const funnel = store.getters['funnel/getSelectedFunnel'];
  if (!funnel?.stages) return [];

  return Object.entries(funnel.stages)
    .map(([id, stage]) => ({
      id,
      name: stage.name,
      position: stage.position,
    }))
    .sort((a, b) => a.position - b.position);
});

const toggleItem = itemId => {
  const index = selectedItems.value.indexOf(itemId);
  if (index === -1) {
    selectedItems.value.push(itemId);
  } else {
    selectedItems.value.splice(index, 1);
  }
};

const toggleSelectAll = () => {
  if (selectedItems.value.length === props.items.length) {
    selectedItems.value = [];
  } else {
    selectedItems.value = props.items.map(item => item.id);
  }
};

const isAllSelected = computed(() => {
  return selectedItems.value.length === props.items.length;
});

const handleConfirm = () => {
  if (selectedStage.value && selectedItems.value.length > 0) {
    emit('confirm', {
      itemIds: selectedItems.value,
      stageId: selectedStage.value,
    });
  }
};
</script>

<template>
  <div class="bulk-move-modal">
    <div class="p-6">
      <h3 class="text-lg font-medium mb-4">
        {{ t('KANBAN.BULK_ACTIONS.MOVE.TITLE') }}
      </h3>
      <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
        {{ t('KANBAN.BULK_ACTIONS.MOVE.DESCRIPTION') }}
      </p>

      <div class="stage-selector mb-4">
        <label class="block text-sm font-medium mb-2">
          {{ t('KANBAN.BULK_ACTIONS.SELECT_STAGE') }}
        </label>
        <select
          v-model="selectedStage"
          class="w-full p-2 border rounded-lg bg-white dark:bg-slate-800"
        >
          <option value="" disabled>
            {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.STAGE.PLACEHOLDER') }}
          </option>
          <option v-for="stage in stages" :key="stage.id" :value="stage.id">
            {{ stage.name }}
          </option>
        </select>
      </div>

      <div class="items-list max-h-96 overflow-y-auto mb-4">
        <!-- Select All Header -->
        <div
          class="item-row flex items-center p-3 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg cursor-pointer"
          @click="toggleSelectAll"
        >
          <input
            type="checkbox"
            :checked="isAllSelected"
            class="mr-3"
            @click.stop
          />
          <div class="flex-1">
            <h4 class="text-sm font-medium">
              {{ t('KANBAN.BULK_ACTIONS.SELECT_ALL') }}
            </h4>
          </div>
        </div>

        <!-- Individual Items -->
        <div
          v-for="item in items"
          :key="item.id"
          class="item-row flex items-center p-3 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg cursor-pointer"
          :class="{
            'bg-slate-50 dark:bg-slate-800': selectedItems.includes(item.id),
          }"
          @click="toggleItem(item.id)"
        >
          <input
            type="checkbox"
            :checked="selectedItems.includes(item.id)"
            class="mr-3"
            @click.stop
          />
          <div class="flex-1">
            <h4 class="text-sm font-medium">
              {{
                item.item_details?.title ||
                item.title ||
                t('KANBAN.ITEM_DETAILS.UNTITLED_ITEM')
              }}
            </h4>
            <div class="flex items-center gap-2 mt-1">
              <span
                class="px-2 py-1 text-xs font-medium rounded-full"
                :class="`bg-${item.item_details?.priority || item.priority || 'none'}-50 dark:bg-${item.item_details?.priority || item.priority || 'none'}-800 text-${item.item_details?.priority || item.priority || 'none'}-800 dark:text-${item.item_details?.priority || item.priority || 'none'}-50`"
              >
                {{
                  t(
                    `KANBAN.PRIORITY_LABELS.${(item.item_details?.priority || item.priority || 'NONE').toUpperCase()}`
                  )
                }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="flex justify-end gap-2">
        <woot-button variant="clear" size="small" @click="$emit('close')">
          {{ t('KANBAN.BULK_ACTIONS.CANCEL') }}
        </woot-button>
        <woot-button
          variant="primary"
          size="small"
          :disabled="!selectedStage || !selectedItems.length"
          @click="handleConfirm"
        >
          {{
            t('KANBAN.BULK_ACTIONS.CONFIRM', {
              count: selectedItems.length,
            })
          }}
        </woot-button>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.bulk-move-modal {
  width: 100%;
  max-width: 600px;
}

.items-list {
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-normal);
  padding: var(--space-small);
}

.item-row {
  border-bottom: 1px solid var(--color-border);
  transition: all 0.2s ease;

  &:last-child {
    border-bottom: none;
  }
}
</style>
