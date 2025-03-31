<script setup>
import { Position, Handle } from '@vue-flow/core';

defineProps({
  data: {
    type: Object,
    required: true,
  },
  selected: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <div class="condition-node">
    <div class="node-header">
      <div class="node-icon">
        <i class="material-icons">call_split</i>
      </div>
      <div class="node-title">{{ data.label }}</div>
    </div>
    <div class="node-content">
      <div class="condition-details">
        <div class="condition-field">{{ data.field || 'Field' }}</div>
        <div class="condition-operator">{{ data.operator || '==' }}</div>
        <div class="condition-value">
          {{ data.value?.toString() || 'Value' }}
        </div>
      </div>
    </div>
    <Handle type="target" :position="Position.Top" />
    <Handle type="source" :position="Position.Bottom" id="a" />
  </div>
</template>

<style scoped>
.condition-node {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  min-width: 180px;
  font-size: 14px;
}

.node-header {
  display: flex;
  align-items: center;
  background: #ca8a04;
  color: white;
  padding: 8px 12px;
  border-radius: 6px 6px 0 0;
}

.node-icon {
  display: flex;
  align-items: center;
  margin-right: 8px;
}

.node-icon i {
  font-size: 16px;
}

.node-title {
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.node-content {
  padding: 8px 12px;
}

.condition-details {
  display: flex;
  gap: 4px;
  align-items: center;
  margin-top: 4px;
  font-size: 12px;
  color: #6b7280;
}

.condition-field {
  font-weight: 500;
}

.condition-operator {
  color: #9ca3af;
}

.condition-value {
  color: #1f2937;
  font-weight: 500;
}
</style>
