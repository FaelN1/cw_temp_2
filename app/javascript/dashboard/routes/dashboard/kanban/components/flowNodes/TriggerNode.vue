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
  <div class="trigger-node">
    <div class="node-header">
      <div class="node-icon">
        <i class="material-icons">chat</i>
      </div>
      <div class="node-title">{{ data.label }}</div>
    </div>
    <div class="node-content">
      <div class="node-description">Event Trigger</div>
    </div>
    <Handle type="source" :position="Position.Bottom" />
  </div>
</template>

<style scoped>
.trigger-node {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  min-width: 180px;
  font-size: 14px;
}

.node-header {
  display: flex;
  align-items: center;
  background: #4338ca;
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

.node-description {
  color: #6b7280;
  font-size: 12px;
  margin-top: 4px;
}
</style>
