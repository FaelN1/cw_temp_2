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

const getActionIcon = type => {
  switch (type) {
    case 'send_message':
      return 'send';
    case 'change_status':
      return 'sync';
    case 'assign_agent':
      return 'person';
    case 'add_label':
      return 'label';
    case 'move_to_column':
      return 'view_column';
    case 'change_priority':
      return 'priority_high';
    default:
      return 'flash_on';
  }
};

// Função para obter o rótulo do tipo de ação
const getActionTypeLabel = type => {
  const typeMap = {
    send_message: 'Enviar mensagem',
    change_status: 'Alterar status',
    move_to_column: 'Mover para coluna',
    assign_agent: 'Atribuir a agente',
    add_label: 'Adicionar etiqueta',
    change_priority: 'Alterar prioridade',
    send_notification: 'Enviar notificação',
  };

  return typeMap[type] || type;
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
      <div class="action-content">
        <div class="action-type">
          {{ getActionTypeLabel(node.data.type) }}
        </div>
        <div class="action-details">
          <div v-if="node.data.description" class="action-description">
            {{ node.data.description }}
          </div>
          <div v-if="node.data.message" class="action-message">
            "{{ node.data.message }}"
          </div>
          <div v-if="node.data.target" class="action-target">
            → {{ node.data.target }}
          </div>
        </div>
      </div>
    </template>
  </BaseNode>
</template>

<style lang="scss" scoped>
.action-node {
  color: #334155;
}

.node-header {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 500;
  margin-bottom: 8px;

  &.action {
    color: #3b82f6;
  }

  .action-icon {
    font-size: 16px;
  }

  .action-label {
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

.action-content {
  .action-type {
    font-weight: 500;
    margin-bottom: 8px;
    color: #3b82f6;
  }

  .action-details {
    @apply text-sm text-slate-600 dark:text-slate-400;

    .action-description {
      margin-bottom: 6px;
    }

    .action-message {
      font-style: italic;
      margin-bottom: 6px;
    }

    .action-target {
      font-weight: 500;
    }
  }
}
</style>
