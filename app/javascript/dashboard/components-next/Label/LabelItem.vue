<script setup>
import { computed } from 'vue';

const props = defineProps({
  label: {
    type: Object,
    required: true,
  },
  isHovered: {
    type: Boolean,
    default: false,
  },
});

const emits = defineEmits(['remove', 'hover']);

const formattedTitle = computed(() => {
  return props.label.contacts_count > 0
    ? `${props.label.title} (${props.label.contacts_count})`
    : props.label.title;
});

const handleHover = () => {
  emits('hover');
};

const handleRemove = () => {
  emits('remove', props.label.id);
};
</script>

<template>
  <div
    class="flex items-center gap-1.5 px-2 py-1 bg-n-slate-1 dark:bg-n-slate-8 rounded-md"
    @mouseover="handleHover"
  >
    <div
      class="size-2 rounded-full"
      :style="{ backgroundColor: label.color }"
    ></div>
    <span class="text-sm">{{ formattedTitle }}</span>
    <button
      v-if="isHovered"
      class="p-0.5 hover:bg-n-slate-3 dark:hover:bg-n-slate-6 rounded"
      @click="handleRemove"
    >
      <fluent-icon icon="dismiss" size="12" />
    </button>
  </div>
</template>
