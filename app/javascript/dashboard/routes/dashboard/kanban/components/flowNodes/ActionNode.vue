<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { Handle, Position } from '@vue-flow/core';

const props = defineProps({
  id: {
    type: String,
    required: true,
  },
  data: {
    type: Object,
    required: true,
  },
  selected: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();

// Obter dados do store
const funnels = computed(() => store.getters['funnel/getFunnels'] || []);
const agentsList = computed(() => store.getters['agents/getAgents'] || []);

const columns = computed(() => {
  // Obter todas as colunas de todos os funis
  const allColumns = [];
  funnels.value.forEach(funnel => {
    if (funnel.stages) {
      Object.entries(funnel.stages).forEach(([id, stage]) => {
        allColumns.push({
          id,
          title: `${funnel.name} - ${stage.name}`,
          funnelId: funnel.id,
          color: stage.color,
        });
      });
    }
  });
  return allColumns;
});

const priorityOptions = [
  { value: 'urgent', label: t('PRIORITY_LABELS.URGENT') },
  { value: 'high', label: t('PRIORITY_LABELS.HIGH') },
  { value: 'medium', label: t('PRIORITY_LABELS.MEDIUM') },
  { value: 'low', label: t('PRIORITY_LABELS.LOW') },
  { value: 'none', label: t('PRIORITY_LABELS.NONE') },
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
  {
    value: 'send_message',
    label: t('KANBAN.AUTOMATIONS.FLOW.ACTIONS.SEND_MESSAGE'),
  },
  {
    value: 'update_contact',
    label: t('KANBAN.AUTOMATIONS.FLOW.ACTIONS.UPDATE_CONTACT'),
  },
  {
    value: 'add_label',
    label: t('KANBAN.AUTOMATIONS.FLOW.ACTIONS.ADD_LABEL'),
  },
];

const updateActionType = event => {
  const newType = event.target.value;
  let newData = { ...props.data, type: newType };

  // Adicionar propriedades específicas para cada tipo de ação
  switch (newType) {
    case 'move_to_column':
      newData.column = columns.value.length > 0 ? columns.value[0].id : '';
      break;
    case 'change_priority':
      newData.priority = 'medium';
      break;
    case 'assign_agent':
      newData.agent_id = '';
      break;
    case 'send_notification':
    case 'send_message':
      newData.message = '';
      if (newType === 'send_message') {
        newData.conversation_id = '';
      }
      break;
    case 'update_contact':
      newData.contact_id = '';
      newData.attributes = {};
      break;
    case 'add_label':
      newData.label = '';
      break;
    default:
      // Não fazer nada para tipos desconhecidos
      break;
  }

  store.dispatch('automationEditor/updateNodeData', {
    nodeId: props.id,
    data: newData,
  });
};

const updateColumn = event => {
  store.dispatch('automationEditor/updateNodeData', {
    nodeId: props.id,
    data: { ...props.data, column: event.target.value },
  });
};

const updatePriority = event => {
  store.dispatch('automationEditor/updateNodeData', {
    nodeId: props.id,
    data: { ...props.data, priority: event.target.value },
  });
};

const updateAgentId = event => {
  store.dispatch('automationEditor/updateNodeData', {
    nodeId: props.id,
    data: { ...props.data, agent_id: event.target.value },
  });
};

const updateMessage = event => {
  store.dispatch('automationEditor/updateNodeData', {
    nodeId: props.id,
    data: { ...props.data, message: event.target.value },
  });
};

const updateLabel = event => {
  store.dispatch('automationEditor/updateNodeData', {
    nodeId: props.id,
    data: { ...props.data, label: event.target.value },
  });
};

const getActionTypeLabel = type => {
  const actionType = actionTypes.find(item => item.value === type);
  return actionType ? actionType.label : type;
};

const isEditing = ref(false);
const nodeRef = ref(null);

// Handler para cliques no nó
const handleNodeClick = () => {
  isEditing.value = true;
};

// Handler para cliques fora do nó
const handleClickOutside = event => {
  if (nodeRef.value && !nodeRef.value.contains(event.target)) {
    isEditing.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside);
});
</script>

<template>
  <div
    ref="nodeRef"
    class="action-node"
    :class="{ 'is-editing': isEditing }"
    @click.stop="handleNodeClick"
  >
    <Handle type="target" position="top" />
    <Handle type="source" position="bottom" />

    <div class="node-header noevents">
      <div class="node-icon">
        <i class="material-icons">flash_on</i>
      </div>
      <div class="node-title">{{ data.label }}</div>
    </div>

    <div class="node-content nodrag">
      <div class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.ACTIONS.TYPE.LABEL')
        }}</label>
        <select
          :value="data.type"
          class="form-select"
          @change="updateActionType"
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

      <!-- Move to column -->
      <div v-if="data.type === 'move_to_column'" class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.ACTIONS.COLUMN.LABEL')
        }}</label>
        <select :value="data.column" class="form-select" @change="updateColumn">
          <option v-for="column in columns" :key="column.id" :value="column.id">
            {{ column.title }}
          </option>
        </select>
      </div>

      <!-- Change priority -->
      <div v-if="data.type === 'change_priority'" class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.ACTIONS.PRIORITY.LABEL')
        }}</label>
        <select
          :value="data.priority"
          class="form-select"
          @change="updatePriority"
        >
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
      <div v-if="data.type === 'assign_agent'" class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.ACTIONS.AGENT.LABEL')
        }}</label>
        <select
          :value="data.agent_id"
          class="form-select"
          @change="updateAgentId"
        >
          <option value="">{{ t('KANBAN.NO_AGENT') }}</option>
          <option v-for="agent in agentsList" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </div>

      <!-- Send notification or message -->
      <div
        v-if="data.type === 'send_notification' || data.type === 'send_message'"
        class="form-group"
      >
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FORM.ACTIONS.NOTIFICATION.LABEL')
        }}</label>
        <textarea
          :value="data.message"
          class="form-textarea"
          :placeholder="
            t('KANBAN.AUTOMATIONS.FORM.ACTIONS.NOTIFICATION.PLACEHOLDER')
          "
          rows="2"
          @input="updateMessage"
        />
      </div>

      <!-- Add label -->
      <div v-if="data.type === 'add_label'" class="form-group">
        <label class="form-label">{{
          t('KANBAN.AUTOMATIONS.FLOW.ACTIONS.ADD_LABEL')
        }}</label>
        <input
          :value="data.label"
          type="text"
          class="form-input"
          :placeholder="
            t('KANBAN.AUTOMATIONS.FLOW.ACTIONS.ADD_LABEL_PLACEHOLDER')
          "
          @input="updateLabel"
        />
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.action-node {
  @apply bg-white dark:bg-slate-700 rounded-lg shadow-md border border-slate-200 
    dark:border-slate-600 overflow-hidden min-w-[300px];

  &.is-editing {
    @apply ring-2 ring-green-500;
  }
}

.node-header {
  @apply flex items-center p-3 bg-green-500 text-white font-medium;
}

.node-content {
  @apply p-3;
}

.form-group {
  @apply mb-3 last:mb-0;
}

.form-label {
  @apply block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1;
}

.form-select,
.form-input,
.form-textarea {
  @apply w-full rounded-md border border-slate-300 dark:border-slate-600 
    bg-white dark:bg-slate-800 px-3 py-1.5 text-sm text-slate-800 dark:text-slate-200
    focus:border-green-500 focus:ring-1 focus:ring-green-500;
}

.form-textarea {
  @apply resize-none;
}

.noevents {
  pointer-events: none;
}

.node-icon {
  display: flex;
  align-items: center;
  margin-right: 8px;
}

.node-title {
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
