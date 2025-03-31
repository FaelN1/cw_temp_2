<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

const props = defineProps({
  automation: {
    type: Object,
    default: null,
  },
  columns: {
    type: Array,
    required: true,
  },
  funnels: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['save', 'cancel']);

const { t } = useI18n();
const store = useStore();

const agentsList = computed(() => {
  return store.getters['agents/getAgents'] || [];
});

const form = ref({
  id: props.automation?.id || null,
  name: props.automation?.name || '',
  description: props.automation?.description || '',
  active:
    props.automation?.active !== undefined ? props.automation?.active : true,
  trigger: {
    type: props.automation?.trigger?.type || 'item_created',
    column: props.automation?.trigger?.column || 'all',
    inactivity_period: props.automation?.trigger?.inactivity_period || 7,
  },
  conditions: props.automation?.conditions || [],
  actions: props.automation?.actions || [],
});

const triggerTypes = [
  {
    value: 'item_created',
    label: t('KANBAN.AUTOMATIONS.FORM.TRIGGER.TYPE.ITEM_CREATED'),
  },
  {
    value: 'item_updated',
    label: t('KANBAN.AUTOMATIONS.FORM.TRIGGER.TYPE.ITEM_UPDATED'),
  },
  {
    value: 'item_moved',
    label: t('KANBAN.AUTOMATIONS.FORM.TRIGGER.TYPE.ITEM_MOVED'),
  },
  {
    value: 'inactivity',
    label: t('KANBAN.AUTOMATIONS.FORM.TRIGGER.TYPE.INACTIVITY'),
  },
];

const conditionFields = [
  {
    value: 'title',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.FIELD.TITLE'),
  },
  {
    value: 'description',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.FIELD.DESCRIPTION'),
  },
  {
    value: 'priority',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.FIELD.PRIORITY'),
  },
  {
    value: 'value',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.FIELD.VALUE'),
  },
  {
    value: 'agent',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.FIELD.AGENT'),
  },
];

const conditionOperators = [
  {
    value: 'equals',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.OPERATOR.EQUALS'),
  },
  {
    value: 'not_equals',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.OPERATOR.NOT_EQUALS'),
  },
  {
    value: 'contains',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.OPERATOR.CONTAINS'),
  },
  {
    value: 'not_contains',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.OPERATOR.NOT_CONTAINS'),
  },
  {
    value: 'greater_than',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.OPERATOR.GREATER_THAN'),
  },
  {
    value: 'less_than',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.OPERATOR.LESS_THAN'),
  },
  {
    value: 'is_empty',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.OPERATOR.IS_EMPTY'),
  },
  {
    value: 'is_not_empty',
    label: t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.OPERATOR.IS_NOT_EMPTY'),
  },
];

const actionTypes = [
  {
    value: 'move_to_column',
    label: t('KANBAN.AUTOMATIONS.FORM.ACTIONS.TYPE.MOVE_TO_COLUMN'),
  },
  {
    value: 'change_priority',
    label: t('KANBAN.AUTOMATIONS.FORM.ACTIONS.TYPE.CHANGE_PRIORITY'),
  },
  {
    value: 'assign_agent',
    label: t('KANBAN.AUTOMATIONS.FORM.ACTIONS.TYPE.ASSIGN_AGENT'),
  },
  {
    value: 'send_notification',
    label: t('KANBAN.AUTOMATIONS.FORM.ACTIONS.TYPE.SEND_NOTIFICATION'),
  },
];

const priorityOptions = [
  { value: 'urgent', label: t('PRIORITY_LABELS.URGENT') },
  { value: 'high', label: t('PRIORITY_LABELS.HIGH') },
  { value: 'medium', label: t('PRIORITY_LABELS.MEDIUM') },
  { value: 'low', label: t('PRIORITY_LABELS.LOW') },
  { value: 'none', label: t('PRIORITY_LABELS.NONE') },
];

// Funnel e etapas selecionadas
const findFunnelIdForColumn = columnId => {
  if (!columnId || columnId === 'all') return null;

  // Procurar em qual funil está a coluna usando find
  const matchingFunnel = props.funnels.find(
    funnel => funnel.stages && Object.keys(funnel.stages).includes(columnId)
  );

  return matchingFunnel ? matchingFunnel.id : null;
};

// Inicializar com o funil da coluna da automação, se existir
const initialFunnelId = props.automation?.trigger?.column
  ? findFunnelIdForColumn(props.automation.trigger.column)
  : null;

const selectedFunnelId = ref(initialFunnelId);

const selectedFunnel = computed(() => {
  if (!selectedFunnelId.value) return null;
  return props.funnels.find(f => f.id === selectedFunnelId.value) || null;
});

const funnelStages = computed(() => {
  if (!selectedFunnel.value || !selectedFunnel.value.stages) return [];

  return Object.entries(selectedFunnel.value.stages).map(([id, stage]) => ({
    id,
    title: stage.name,
    color: stage.color,
  }));
});

const addCondition = () => {
  form.value.conditions.push({
    field: 'title',
    operator: 'contains',
    value: '',
  });
};

const removeCondition = index => {
  form.value.conditions.splice(index, 1);
};

const addAction = () => {
  form.value.actions.push({
    type: 'move_to_column',
    column: props.columns.length > 0 ? props.columns[0].id : '',
  });
};

const removeAction = index => {
  form.value.actions.splice(index, 1);
};

const handleActionTypeChange = (action, newType) => {
  action.type = newType;

  // Adicionar propriedades específicas do tipo de ação
  if (newType === 'move_to_column') {
    action.column = props.columns.length > 0 ? props.columns[0].id : '';
  } else if (newType === 'change_priority') {
    action.priority = 'medium';
  } else if (newType === 'assign_agent') {
    action.agent_id = '';
  } else if (newType === 'send_notification') {
    action.message = '';
  }
};

const handleSubmit = () => {
  emit('save', { ...form.value });
};

const showInactivityPeriod = computed(() => {
  return form.value.trigger.type === 'inactivity';
});

// Observar mudanças no funil selecionado
watch(selectedFunnelId, newFunnelId => {
  if (newFunnelId && selectedFunnel.value && selectedFunnel.value.stages) {
    // Se um novo funil for selecionado, atualizar a coluna para a primeira etapa desse funil
    const stageIds = Object.keys(selectedFunnel.value.stages);
    if (stageIds.length > 0) {
      form.value.trigger.column = stageIds[0];

      // Atualizar também as ações de mover para coluna
      form.value.actions.forEach(action => {
        if (action.type === 'move_to_column') {
          action.column = stageIds[0];
        }
      });
    }
  } else if (!newFunnelId) {
    // Se nenhum funil for selecionado, voltar para "todas as colunas"
    form.value.trigger.column = 'all';
  }
});
</script>

<template>
  <form @submit.prevent="handleSubmit" class="automation-form">
    <div class="form-section">
      <div class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.NAME.LABEL')
        }}</label>
        <input
          v-model="form.name"
          type="text"
          class="form-input"
          :placeholder="t('KANBAN.AUTOMATIONS.FORM.NAME.PLACEHOLDER')"
          required
        />
      </div>

      <div class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.DESCRIPTION.LABEL')
        }}</label>
        <textarea
          v-model="form.description"
          class="form-textarea"
          :placeholder="t('KANBAN.AUTOMATIONS.FORM.DESCRIPTION.PLACEHOLDER')"
          rows="2"
        />
      </div>

      <div class="form-group">
        <label class="form-label flex items-center gap-2">
          <input type="checkbox" v-model="form.active" class="form-checkbox" />
          {{ t('KANBAN.AUTOMATIONS.FORM.ACTIVE.LABEL') }}
        </label>
      </div>
    </div>

    <div class="form-section">
      <h3 class="section-title">
        {{ t('KANBAN.AUTOMATIONS.FORM.TRIGGER.TITLE') }}
      </h3>

      <div class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.TRIGGER.TYPE.LABEL')
        }}</label>
        <select v-model="form.trigger.type" class="form-select">
          <option
            v-for="type in triggerTypes"
            :key="type.value"
            :value="type.value"
          >
            {{ type.label }}
          </option>
        </select>
      </div>

      <!-- Seleção de Funil -->
      <div class="form-group">
        <label class="form-label">{{ t('KANBAN.FORM.FUNNEL.LABEL') }}</label>
        <select v-model="selectedFunnelId" class="form-select">
          <option value="">{{ t('KANBAN.SELECT_FUNNEL') }}</option>
          <option v-for="funnel in funnels" :key="funnel.id" :value="funnel.id">
            {{ funnel.name }}
          </option>
        </select>
      </div>

      <!-- Seleção de Etapa -->
      <div class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.TRIGGER.COLUMN.LABEL')
        }}</label>
        <select v-model="form.trigger.column" class="form-select">
          <option value="all">
            {{ t('KANBAN.AUTOMATIONS.FORM.TRIGGER.COLUMN.ALL') }}
          </option>
          <!-- Mostrar etapas do funil selecionado -->
          <optgroup v-if="selectedFunnel" :label="selectedFunnel.name">
            <option
              v-for="stage in funnelStages"
              :key="stage.id"
              :value="stage.id"
            >
              {{ stage.title }}
            </option>
          </optgroup>
          <!-- Mostrar todas as colunas se nenhum funil for selecionado -->
          <template v-if="!selectedFunnel">
            <option
              v-for="column in columns"
              :key="column.id"
              :value="column.id"
            >
              {{ column.title }}
            </option>
          </template>
        </select>
      </div>

      <div v-if="showInactivityPeriod" class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.TRIGGER.INACTIVITY_PERIOD.LABEL')
        }}</label>
        <div class="flex items-center gap-2">
          <input
            v-model.number="form.trigger.inactivity_period"
            type="number"
            min="1"
            class="form-input"
            required
          />
          <span>{{
            t('KANBAN.AUTOMATIONS.FORM.TRIGGER.INACTIVITY_PERIOD.DAYS')
          }}</span>
        </div>
      </div>
    </div>

    <div class="form-section">
      <div class="section-header">
        <h3 class="section-title">
          {{ t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.TITLE') }}
        </h3>
        <button type="button" class="add-button" @click="addCondition">
          <fluent-icon icon="add" size="16" />
          {{ t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.ADD_CONDITION') }}
        </button>
      </div>

      <div v-if="form.conditions.length === 0" class="empty-message">
        {{ t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.ADD_CONDITION') }}
      </div>

      <div
        v-for="(condition, index) in form.conditions"
        :key="index"
        class="condition-row"
      >
        <div class="condition-fields">
          <select v-model="condition.field" class="form-select">
            <option
              v-for="field in conditionFields"
              :key="field.value"
              :value="field.value"
            >
              {{ field.label }}
            </option>
          </select>

          <select v-model="condition.operator" class="form-select">
            <option
              v-for="operator in conditionOperators"
              :key="operator.value"
              :value="operator.value"
            >
              {{ operator.label }}
            </option>
          </select>

          <input
            v-if="!['is_empty', 'is_not_empty'].includes(condition.operator)"
            v-model="condition.value"
            type="text"
            class="form-input"
            :placeholder="
              t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.VALUE.PLACEHOLDER')
            "
          />
        </div>

        <button
          type="button"
          class="remove-button"
          @click="removeCondition(index)"
        >
          <fluent-icon icon="dismiss" size="16" />
        </button>
      </div>
    </div>

    <div class="form-section">
      <div class="section-header">
        <h3 class="section-title">
          {{ t('KANBAN.AUTOMATIONS.FORM.ACTIONS.TITLE') }}
        </h3>
        <button type="button" class="add-button" @click="addAction">
          <fluent-icon icon="add" size="16" />
          {{ t('KANBAN.AUTOMATIONS.FORM.ACTIONS.ADD_ACTION') }}
        </button>
      </div>

      <div v-if="form.actions.length === 0" class="empty-message">
        {{ t('KANBAN.AUTOMATIONS.FORM.ACTIONS.ADD_ACTION') }}
      </div>

      <div
        v-for="(action, index) in form.actions"
        :key="index"
        class="action-row"
      >
        <div class="action-type">
          <select
            v-model="action.type"
            class="form-select"
            @change="handleActionTypeChange(action, $event.target.value)"
          >
            <option
              v-for="type in actionTypes"
              :key="type.value"
              :value="type.value"
            >
              {{ type.label }}
            </option>
          </select>
        </div>

        <div class="action-details">
          <!-- Move to column -->
          <div v-if="action.type === 'move_to_column'" class="form-group">
            <label class="form-label">{{
              t('KANBAN.AUTOMATIONS.FORM.ACTIONS.COLUMN.LABEL')
            }}</label>
            <select v-model="action.column" class="form-select">
              <!-- Mostrar etapas do funil selecionado -->
              <optgroup v-if="selectedFunnel" :label="selectedFunnel.name">
                <option
                  v-for="stage in funnelStages"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.title }}
                </option>
              </optgroup>
              <!-- Mostrar todas as colunas se nenhum funil for selecionado -->
              <template v-if="!selectedFunnel">
                <option
                  v-for="column in columns"
                  :key="column.id"
                  :value="column.id"
                >
                  {{ column.title }}
                </option>
              </template>
            </select>
          </div>

          <!-- Change priority -->
          <div v-if="action.type === 'change_priority'" class="form-group">
            <label class="form-label">{{
              t('KANBAN.AUTOMATIONS.FORM.ACTIONS.PRIORITY.LABEL')
            }}</label>
            <select v-model="action.priority" class="form-select">
              <option
                v-for="priority in priorityOptions"
                :key="priority.value"
                :value="priority.value"
              >
                {{ priority.label }}
              </option>
            </select>
          </div>

          <!-- Assign agent -->
          <div v-if="action.type === 'assign_agent'" class="form-group">
            <label class="form-label">{{
              t('KANBAN.AUTOMATIONS.FORM.ACTIONS.AGENT.LABEL')
            }}</label>
            <select v-model="action.agent_id" class="form-select">
              <option value="">{{ t('KANBAN.NO_AGENT') }}</option>
              <option
                v-for="agent in agentsList"
                :key="agent.id"
                :value="agent.id"
              >
                {{ agent.name }}
              </option>
            </select>
          </div>

          <!-- Send notification -->
          <div v-if="action.type === 'send_notification'" class="form-group">
            <label class="form-label">{{
              t('KANBAN.AUTOMATIONS.FORM.ACTIONS.NOTIFICATION.LABEL')
            }}</label>
            <textarea
              v-model="action.message"
              class="form-textarea"
              :placeholder="
                t('KANBAN.AUTOMATIONS.FORM.ACTIONS.NOTIFICATION.PLACEHOLDER')
              "
              rows="2"
            />
          </div>
        </div>

        <button
          type="button"
          class="remove-button"
          @click="removeAction(index)"
        >
          <fluent-icon icon="dismiss" size="16" />
        </button>
      </div>
    </div>

    <div class="form-footer">
      <woot-button
        variant="clear"
        color-scheme="secondary"
        @click="$emit('cancel')"
      >
        {{ t('CANCEL') }}
      </woot-button>
      <woot-button variant="solid" color-scheme="primary" type="submit">
        {{ t('SAVE') }}
      </woot-button>
    </div>
  </form>
</template>

<style lang="scss" scoped>
.automation-form {
  @apply space-y-6;
}

.form-section {
  @apply bg-slate-50 dark:bg-slate-800 rounded-lg p-4;
}

.section-header {
  @apply flex justify-between items-center mb-4;
}

.section-title {
  @apply text-sm font-medium text-slate-700 dark:text-slate-300 mb-4;
}

.form-group {
  @apply mb-4 last:mb-0;
}

.form-label {
  @apply block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1;
}

.form-input,
.form-select,
.form-textarea {
  @apply w-full rounded-md border border-slate-300 dark:border-slate-600 
    bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-800 dark:text-slate-200
    focus:border-woot-500 focus:ring-1 focus:ring-woot-500;
}

.form-textarea {
  @apply resize-none;
}

.form-checkbox {
  @apply rounded border-slate-300 dark:border-slate-600 text-woot-500
    focus:ring-woot-500 h-4 w-4;
}

.add-button {
  @apply flex items-center gap-1 text-sm font-medium text-woot-500 hover:text-woot-600
    dark:text-woot-400 dark:hover:text-woot-300;
}

.empty-message {
  @apply text-center py-4 text-sm text-slate-500 dark:text-slate-400 italic;
}

.condition-row,
.action-row {
  @apply flex items-start gap-2 mb-3 last:mb-0 p-3 bg-white dark:bg-slate-700 rounded-md
    border border-slate-200 dark:border-slate-600;
}

.condition-fields {
  @apply flex-1 grid grid-cols-3 gap-2;
}

.action-type {
  @apply w-1/3;
}

.action-details {
  @apply flex-1;
}

.remove-button {
  @apply p-1 text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-300
    hover:bg-slate-100 dark:hover:bg-slate-600 rounded;
}

.form-footer {
  @apply flex justify-end gap-2 pt-4 border-t border-slate-200 dark:border-slate-700;
}
</style>
