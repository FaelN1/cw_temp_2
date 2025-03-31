<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import Modal from '../../../../components/Modal.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  columns: {
    type: Array,
    default: () => [],
  },
  filteredResults: {
    type: Object,
    default: () => ({ total: 0, stages: {} }),
  },
  currentFunnel: {
    type: Object,
    default: null,
  },
  agents: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();
const store = useStore();

const emit = defineEmits(['apply', 'close', 'filter-results']);

const filters = ref({
  priority: [],
  value: {
    min: null,
    max: null,
  },
  agent_id: null,
  date: {
    start: null,
    end: null,
  },
});

const priorityOptions = computed(() => [
  {
    label: 'Alta',
    value: 'high',
    colors: {
      border: filters.value.priority.includes('high')
        ? 'border-ruby-500 dark:border-ruby-400'
        : 'border-slate-300 dark:border-slate-600',
      text: filters.value.priority.includes('high')
        ? 'text-ruby-700 dark:text-ruby-300'
        : 'text-slate-700 dark:text-slate-300',
      hover: 'hover:bg-slate-100 dark:hover:bg-slate-700',
      selected:
        'bg-ruby-50 dark:bg-ruby-800 border-ruby-500 dark:border-ruby-400',
    },
  },
  {
    label: 'Média',
    value: 'medium',
    colors: {
      border: filters.value.priority.includes('medium')
        ? 'border-yellow-500 dark:border-yellow-400'
        : 'border-slate-300 dark:border-slate-600',
      text: filters.value.priority.includes('medium')
        ? 'text-yellow-700 dark:text-yellow-300'
        : 'text-slate-700 dark:text-slate-300',
      hover: 'hover:bg-slate-100 dark:hover:bg-slate-700',
      selected:
        'bg-yellow-50 dark:bg-yellow-800 border-yellow-500 dark:border-yellow-400',
    },
  },
  {
    label: 'Baixa',
    value: 'low',
    colors: {
      border: filters.value.priority.includes('low')
        ? 'border-green-500 dark:border-green-400'
        : 'border-slate-300 dark:border-slate-600',
      text: filters.value.priority.includes('low')
        ? 'text-green-700 dark:text-green-300'
        : 'text-slate-700 dark:text-slate-300',
      hover: 'hover:bg-slate-100 dark:hover:bg-slate-700',
      selected:
        'bg-green-50 dark:bg-green-800 border-green-500 dark:border-green-400',
    },
  },
  {
    label: 'Urgente',
    value: 'urgent',
    colors: {
      border: filters.value.priority.includes('urgent')
        ? 'border-ruby-500 dark:border-ruby-400'
        : 'border-slate-300 dark:border-slate-600',
      text: filters.value.priority.includes('urgent')
        ? 'text-ruby-700 dark:text-ruby-300'
        : 'text-slate-700 dark:text-slate-300',
      hover: 'hover:bg-slate-100 dark:hover:bg-slate-700',
      selected:
        'bg-ruby-50 dark:bg-ruby-800 border-ruby-500 dark:border-ruby-400',
    },
  },
]);

const agentsLoaded = ref(false);

onMounted(() => {
  if (store.getters['agents/getAgents'].length === 0) {
    store.dispatch('agents/get');
  }
});

const agents = computed(() => {
  return store.getters['agents/getAgents'] || [];
});

const getStageColor = stageName => {
  if (!props.currentFunnel?.stages) return '#64748B';

  const stage = Object.values(props.currentFunnel.stages).find(
    s => s.name === stageName
  );

  if (!stage) {
    const stageById = Object.values(props.currentFunnel.stages).find(
      s => s.id === stageName
    );
    return stageById?.color || '#64748B';
  }

  return stage.color || '#64748B';
};

const hasActiveFilters = computed(() => {
  const hasFilters = Boolean(
    filters.value.priority.length > 0 ||
      filters.value.value.min ||
      filters.value.value.max ||
      filters.value.agent_id ||
      filters.value.date.start ||
      filters.value.date.end
  );

  return hasFilters && props.filteredResults.total > 0;
});

const handleApply = () => {
  const filterParams = {
    priority: filters.value.priority.length > 0 ? filters.value.priority : null,
    value_min: filters.value.value.min,
    value_max: filters.value.value.max,
    date_start: filters.value.date.start,
    date_end: filters.value.date.end,
    ...(filters.value.agent_id && { agent_id: filters.value.agent_id }),
  };

  emit('apply', filterParams);
  emit('close');
};

const handleClear = () => {
  filters.value = {
    priority: [],
    value: {
      min: null,
      max: null,
    },
    agent_id: null,
    date: {
      start: null,
      end: null,
    },
  };
  emit('apply', filters.value);
};

watch(
  () => props.filteredResults,
  () => {},
  { immediate: true }
);

watch(
  () => props.currentFunnel,
  () => {},
  { immediate: true }
);
</script>

<template>
  <Teleport to="body">
    <Modal
      v-if="show"
      :show="show"
      :show-close-button="false"
      @close="$emit('close')"
    >
      <div class="p-4">
        <header class="mb-3 flex justify-between items-center">
          <div class="flex items-center gap-2">
            <h3 class="text-lg font-medium">
              {{ t('KANBAN.FILTER_ITEMS') }}
            </h3>
            <div
              v-if="hasActiveFilters && filteredResults.total > 0"
              class="flex gap-1"
            >
              <div class="results-tag">
                {{ filteredResults.total }} {{ t('KANBAN.FILTER.RESULTS') }}
              </div>
              <div
                v-for="(count, stageName) in filteredResults.stages"
                :key="stageName"
                class="results-tag"
                :style="{ backgroundColor: getStageColor(stageName) }"
              >
                <span class="stage-name">{{ stageName }}</span>
                <span class="count-badge">{{ count }}</span>
              </div>
            </div>
          </div>
          <woot-button
            variant="clear"
            size="small"
            color-scheme="secondary"
            @click="$emit('close')"
          >
            <fluent-icon icon="dismiss" size="16" />
          </woot-button>
        </header>

        <div class="space-y-2">
          <!-- Prioridade -->
          <div class="filter-group">
            <label class="text-sm font-medium mb-1 block">
              {{ t('KANBAN.FORM.PRIORITY.LABEL') }}
            </label>
            <div class="flex flex-wrap gap-1">
              <button
                v-for="option in priorityOptions"
                :key="option.value"
                :class="[
                  'border',
                  filters.priority.includes(option.value)
                    ? option.colors.selected
                    : [option.colors.border, option.colors.hover],
                  option.colors.text,
                  'px-3 py-1 text-sm font-medium rounded-lg transition-colors',
                ]"
                @click="
                  filters.priority = filters.priority.includes(option.value)
                    ? filters.priority.filter(p => p !== option.value)
                    : [...filters.priority, option.value]
                "
              >
                {{ option.label }}
              </button>
            </div>
          </div>

          <!-- Valor -->
          <div class="filter-group">
            <label class="text-sm font-medium mb-1 block">
              {{ t('KANBAN.VALUE.LABEL') }}
            </label>
            <div class="flex gap-2">
              <woot-input
                v-model="filters.value.min"
                type="number"
                :placeholder="t('KANBAN.VALUE.MIN')"
                class="flex-1"
              />
              <woot-input
                v-model="filters.value.max"
                type="number"
                :placeholder="t('KANBAN.VALUE.MAX')"
                class="flex-1"
              />
            </div>
          </div>

          <!-- Agente Responsável -->
          <div class="filter-group">
            <label class="text-sm font-medium mb-1 block">
              {{ t('KANBAN.AGENT.LABEL') }}
            </label>
            <div class="relative">
              <select
                v-model="filters.agent_id"
                class="w-full rounded-lg border border-slate-300 dark:border-slate-700 p-2"
              >
                <option value="">{{ t('KANBAN.FILTER.AGENT.ALL') }}</option>
                <option
                  v-for="agent in agents"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>
            </div>
          </div>

          <!-- Data de Criação -->
          <div class="filter-group">
            <label class="text-sm font-medium mb-1 block">
              {{ t('KANBAN.FILTER.DATE.LABEL') }}
            </label>
            <div class="flex gap-2">
              <woot-input
                v-model="filters.date.start"
                type="date"
                :placeholder="t('KANBAN.FILTER.DATE.START')"
                class="flex-1"
              />
              <woot-input
                v-model="filters.date.end"
                type="date"
                :placeholder="t('KANBAN.FILTER.DATE.END')"
                class="flex-1"
              />
            </div>
          </div>
        </div>

        <footer
          class="flex justify-end space-x-2 pt-3 mt-3 border-t dark:border-slate-700"
        >
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click="handleClear"
          >
            {{ t('KANBAN.FORM.CLEAR') }}
          </woot-button>
          <woot-button
            variant="solid"
            color-scheme="primary"
            @click="handleApply"
          >
            {{ t('KANBAN.FORM.APPLY') }}
          </woot-button>
        </footer>
      </div>
    </Modal>
  </Teleport>
</template>

<style lang="scss" scoped>
.filter-group {
  @apply p-2 bg-slate-50 dark:bg-slate-800 rounded-lg;
}

.loading-spinner {
  @apply w-4 h-4 border-2 border-slate-200 border-t-woot-500 rounded-full animate-spin;
}

.results-tag {
  @apply flex items-center px-2 py-0.5 text-xs font-medium rounded-full
    bg-woot-500 text-white whitespace-nowrap gap-1;

  &:first-child {
    @apply bg-slate-600 dark:bg-slate-700;
  }

  .stage-name {
    @apply text-[10px];
  }

  .count-badge {
    @apply bg-white/20 px-1.5 rounded-full text-[10px] min-w-[18px] text-center;
  }
}
</style>
