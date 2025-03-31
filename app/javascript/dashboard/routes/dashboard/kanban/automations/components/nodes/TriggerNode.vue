<script setup>
import BaseNode from './BaseNode.vue';

const props = defineProps({
  node: {
    type: Object,
    required: true,
  },
  selected: {
    type: Boolean,
    default: false,
  },
  isConnecting: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'click',
  'dragStart',
  'dragEnd',
  'connectStart',
  'connectEnd',
  'mousedown',
  'edit',
  'duplicate',
  'delete',
]);

const getTriggerIcon = type => {
  switch (type) {
    case 'message_received':
      return 'message';
    case 'item_created':
      return 'add_circle';
    case 'status_changed':
      return 'sync';
    default:
      return 'bolt';
  }
};

// Função para obter o rótulo do tipo de trigger
const getTriggerTypeLabel = type => {
  const typeMap = {
    message_received: 'Mensagem recebida',
    item_created: 'Item criado',
    status_changed: 'Status alterado',
    item_moved: 'Item movido',
    scheduled: 'Agendado',
  };

  return typeMap[type] || type;
};

// Função para obter o rótulo da programação
const getScheduleLabel = schedule => {
  const scheduleMap = {
    daily: 'Diariamente',
    weekly: 'Semanalmente',
    monthly: 'Mensalmente',
  };

  return scheduleMap[schedule] || schedule;
};
</script>

<template>
  <BaseNode
    :node="node"
    :selected="selected"
    :isConnecting="isConnecting"
    @click="$emit('click', $event)"
    @dragStart="$emit('dragStart', $event, node)"
    @dragEnd="$emit('dragEnd', $event, node)"
    @connectStart="$emit('connectStart', $event, node, $event[1])"
    @connectEnd="$emit('connectEnd', $event, node, $event[1])"
    @mousedown="$emit('mousedown', $event)"
    @edit="$emit('edit')"
    @duplicate="$emit('duplicate')"
    @delete="$emit('delete')"
  >
    <template #content>
      <div class="trigger-content">
        <div class="trigger-type">
          {{ getTriggerTypeLabel(node.data.type) }}
        </div>

        <!-- Detalhes específicos por tipo de trigger -->
        <div
          v-if="node.data.type === 'message_received'"
          class="trigger-details"
        >
          <div v-if="node.data.pattern" class="trigger-pattern">
            <span class="label">Padrão:</span> {{ node.data.pattern }}
          </div>
        </div>

        <div v-if="node.data.type === 'status_changed'" class="trigger-details">
          <div
            v-if="node.data.fromStatus || node.data.toStatus"
            class="trigger-status-change"
          >
            <span v-if="node.data.fromStatus"
              >De: {{ node.data.fromStatus }}</span
            >
            <span v-if="node.data.fromStatus && node.data.toStatus"> → </span>
            <span v-if="node.data.toStatus"
              >Para: {{ node.data.toStatus }}</span
            >
          </div>
        </div>

        <div v-if="node.data.type === 'item_moved'" class="trigger-details">
          <div
            v-if="node.data.fromColumn || node.data.toColumn"
            class="trigger-column-move"
          >
            <span v-if="node.data.fromColumn"
              >De: {{ node.data.fromColumn }}</span
            >
            <span v-if="node.data.fromColumn && node.data.toColumn"> → </span>
            <span v-if="node.data.toColumn"
              >Para: {{ node.data.toColumn }}</span
            >
          </div>
        </div>

        <div v-if="node.data.type === 'scheduled'" class="trigger-details">
          <div
            v-if="node.data.schedule || node.data.time"
            class="trigger-schedule"
          >
            <span v-if="node.data.schedule">{{
              getScheduleLabel(node.data.schedule)
            }}</span>
            <span v-if="node.data.time"> às {{ node.data.time }}</span>
          </div>
        </div>

        <div v-if="node.data.description" class="trigger-description">
          {{ node.data.description }}
        </div>
      </div>
    </template>
  </BaseNode>
</template>

<style lang="scss" scoped>
.trigger-content {
  .trigger-type {
    font-weight: 500;
    margin-bottom: 8px;
    color: #f59e0b;
  }

  .trigger-details {
    @apply bg-amber-50 dark:bg-amber-900/20 p-2 rounded-md mb-2 text-sm;

    .trigger-pattern,
    .trigger-status-change,
    .trigger-column-move,
    .trigger-schedule {
      @apply text-amber-800 dark:text-amber-300;

      .label {
        @apply font-medium;
      }
    }
  }

  .trigger-description {
    @apply text-xs text-slate-500 dark:text-slate-400 mt-1;
  }
}

.trigger-node {
  color: #334155;
}

.node-header {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 500;
  margin-bottom: 8px;

  &.trigger {
    color: #f97316;
  }

  .trigger-icon {
    font-size: 16px;
  }

  .trigger-label {
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
}

.node-content {
  padding: 2px 0;
}

.node-title {
  font-weight: 600;
  font-size: 14px;
  margin-bottom: 4px;
}

.node-description {
  font-size: 12px;
  color: #64748b;
}
</style>
