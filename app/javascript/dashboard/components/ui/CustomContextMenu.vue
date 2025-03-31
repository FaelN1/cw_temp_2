<script setup>
import { ref, onMounted, onUnmounted } from 'vue';

const props = defineProps({
  x: {
    type: Number,
    required: true,
  },
  y: {
    type: Number,
    required: true,
  },
  show: {
    type: Boolean,
    required: true,
  },
});

const emit = defineEmits(['close']);

const menuRef = ref(null);

const handleClickOutside = event => {
  if (menuRef.value && !menuRef.value.contains(event.target)) {
    emit('close');
  }
};

const handleEscape = event => {
  if (event.key === 'Escape') {
    emit('close');
  }
};

onMounted(() => {
  document.addEventListener('mousedown', handleClickOutside);
  document.addEventListener('keydown', handleEscape);
});

onUnmounted(() => {
  document.removeEventListener('mousedown', handleClickOutside);
  document.removeEventListener('keydown', handleEscape);
});
</script>

<template>
  <Teleport to="body">
    <div
      v-if="show"
      ref="menuRef"
      class="fixed z-[9999]"
      :style="{
        top: `${y}px`,
        left: `${x}px`,
      }"
    >
      <slot />
    </div>
  </Teleport>
</template>

<style lang="scss" scoped>
.fixed {
  position: fixed;
}
</style>
