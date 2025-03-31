<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  items: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['close', 'confirm']);
const { t } = useI18n();

const selectedItems = ref([]);

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

const toggleItem = itemId => {
  const index = selectedItems.value.indexOf(itemId);
  if (index === -1) {
    selectedItems.value.push(itemId);
  } else {
    selectedItems.value.splice(index, 1);
  }
};

const handleConfirm = () => {
  emit('confirm', selectedItems.value);
};
</script>

<template>
  <div class="bulk-delete-modal">
    <div class="p-6">
      <h3 class="text-lg font-medium mb-4">
        {{ t('KANBAN.BULK_ACTIONS.DELETE.TITLE') }}
      </h3>
      <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
        {{ t('KANBAN.BULK_ACTIONS.DELETE.DESCRIPTION') }}
      </p>

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
          variant="danger"
          size="small"
          :disabled="!selectedItems.length"
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
.bulk-delete-modal {
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
