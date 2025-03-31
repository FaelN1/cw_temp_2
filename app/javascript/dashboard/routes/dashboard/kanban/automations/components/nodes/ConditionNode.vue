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

// Função para obter o rótulo do tipo de condição
const getConditionTypeLabel = type => {
  const typeMap = {
    status_equals: 'Status igual a',
    text_contains: 'Texto contém',
    assigned_to: 'Atribuído a',
    priority_is: 'Prioridade é',
    has_label: 'Tem etiqueta',
  };

  return typeMap[type] || type;
};

// Função para obter o rótulo do operador
const getOperatorLabel = operator => {
  const operatorMap = {
    equals: 'igual a',
    not_equals: 'diferente de',
    contains: 'contém',
    greater_than: 'maior que',
    less_than: 'menor que',
    includes: 'inclui',
  };

  return operatorMap[operator] || operator || 'igual a';
};

// Formatar o valor para exibição
const formatValue = value => {
  if (value === undefined || value === null) return '-';
  if (typeof value === 'boolean') return value ? 'Sim' : 'Não';
  if (typeof value === 'string' && value.length > 20)
    return `${value.substring(0, 20)}...`;
  return value;
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
      <div class="condition-content">
        <div class="condition-type">
          {{ getConditionTypeLabel(node.data.type) }}
        </div>
        <div class="condition-expression">
          <span class="condition-field">{{ node.data.field || 'campo' }}</span>
          <span class="condition-operator">{{
            getOperatorLabel(node.data.operator)
          }}</span>
          <span class="condition-value">{{
            formatValue(node.data.value)
          }}</span>
        </div>
        <div v-if="node.data.description" class="condition-description">
          {{ node.data.description }}
        </div>
      </div>
    </template>
  </BaseNode>
</template>

<style lang="scss" scoped>
.condition-content {
  .condition-type {
    font-weight: 500;
    margin-bottom: 8px;
    color: #8b5cf6;
  }

  .condition-expression {
    @apply bg-slate-50 dark:bg-slate-800 p-2 rounded-md mb-2 text-sm;

    .condition-field {
      @apply font-medium text-slate-700 dark:text-slate-300;
    }

    .condition-operator {
      @apply mx-1 text-slate-500 dark:text-slate-400;
    }

    .condition-value {
      @apply font-medium text-purple-600 dark:text-purple-400;
    }
  }

  .condition-description {
    @apply text-xs text-slate-500 dark:text-slate-400;
  }
}
</style>
