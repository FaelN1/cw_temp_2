<script setup>
import { ref, computed, onBeforeUnmount, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { onClickOutside } from '@vueuse/core';
import dashboardIcons from '../components/FluentIcon/dashboard-icons.json';

const { t } = useI18n();

const props = defineProps({
  modelValue: {
    type: String,
    required: true,
  },
  label: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue']);

const pickerRef = ref(null);
const showIconPicker = ref(false);
const searchQuery = ref('');

// Computed para o ícone atual com validação
const currentIcon = computed(() => {
  const iconName = props.modelValue?.replace(/-outline$/, '') || 'chat';
  return availableIcons.value.includes(iconName) ? iconName : 'chat';
});

// Lista de ícones disponíveis com validação
const availableIcons = computed(() => {
  return Object.keys(dashboardIcons)
    .filter(key => dashboardIcons[key]?.path) // Verifica se o ícone tem um path válido
    .map(key => key.replace(/-outline$/, ''));
});

// Lista de ícones filtrada com tratamento de erro
const filteredIcons = computed(() => {
  try {
    const query = searchQuery.value.toLowerCase();
    return availableIcons.value.filter(iconName =>
      iconName.toLowerCase().includes(query)
    );
  } catch (error) {
    console.error('Erro ao filtrar ícones:', error);
    return [];
  }
});

// Agrupa os ícones em linhas de 6 com validação
const groupedIcons = computed(() => {
  const icons = filteredIcons.value || [];
  const groups = [];
  for (let i = 0; i < icons.length; i += 6) {
    groups.push(icons.slice(i, i + 6));
  }
  return groups;
});

// Handlers com tratamento de erro
const handleClickOutside = () => {
  try {
    showIconPicker.value = false;
    searchQuery.value = '';
  } catch (error) {
    console.error('Erro ao fechar picker:', error);
  }
};

const handleKeydown = e => {
  try {
    if (e.key === 'Escape' && showIconPicker.value) {
      showIconPicker.value = false;
      searchQuery.value = '';
    }
  } catch (error) {
    console.error('Erro ao processar tecla:', error);
  }
};

// Event listeners com cleanup adequado
onClickOutside(pickerRef, handleClickOutside);

watch(showIconPicker, isVisible => {
  try {
    if (isVisible) {
      document.addEventListener('keydown', handleKeydown);
    } else {
      document.removeEventListener('keydown', handleKeydown);
      searchQuery.value = '';
    }
  } catch (error) {
    console.error('Erro no watcher:', error);
  }
});

onBeforeUnmount(() => {
  document.removeEventListener('keydown', handleKeydown);
});

const selectIcon = iconName => {
  try {
    if (availableIcons.value.includes(iconName)) {
      emit('update:modelValue', iconName);
      showIconPicker.value = false;
      searchQuery.value = '';
    }
  } catch (error) {
    console.error('Erro ao selecionar ícone:', error);
  }
};

const togglePicker = () => {
  try {
    showIconPicker.value = !showIconPicker.value;
  } catch (error) {
    console.error('Erro ao alternar picker:', error);
  }
};
</script>

<template>
  <div ref="pickerRef" class="icon-picker-wrapper">
    <label v-if="label" class="icon-picker-label">{{ label }}</label>

    <button type="button" class="selected-icon" @click="togglePicker">
      <fluent-icon
        :icon="currentIcon"
        :type="currentIcon.includes('-outline') ? 'outline' : 'solid'"
        size="20"
      />
      <span class="icon-name">{{ currentIcon }}</span>
      <fluent-icon
        :icon="showIconPicker ? 'chevron-up' : 'chevron-down'"
        size="16"
        class="chevron"
      />
    </button>

    <div v-if="showIconPicker" class="icon-picker-modal">
      <div class="search-bar">
        <fluent-icon icon="search" size="16" class="search-icon" />
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="t('KANBAN.SEARCH.PLACEHOLDER')"
          class="search-input"
        />
      </div>

      <div class="icons-grid">
        <div
          v-for="(row, rowIndex) in groupedIcons"
          :key="rowIndex"
          class="icon-row"
        >
          <button
            v-for="iconName in row"
            :key="iconName"
            type="button"
            class="icon-button"
            :class="{ selected: currentIcon === iconName }"
            @click="selectIcon(iconName)"
          >
            <fluent-icon :icon="iconName" size="20" />
            <span class="icon-label">{{ iconName }}</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.icon-picker-wrapper {
  @apply relative;
}

.icon-picker-label {
  @apply block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1;
}

.selected-icon {
  @apply w-full flex items-center gap-2 px-3 py-2 bg-white dark:bg-slate-700 
         border border-slate-200 dark:border-slate-600 rounded-lg text-left;

  .icon-name {
    @apply flex-1 text-sm truncate;
  }

  .chevron {
    @apply text-slate-400;
  }
}

.icon-picker-modal {
  @apply absolute z-50 w-[320px] max-h-[400px] mt-1 p-3
         bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700
         rounded-lg shadow-lg overflow-hidden;
}

.search-bar {
  @apply flex items-center gap-2 px-3 py-2 mb-3
         bg-slate-50 dark:bg-slate-700 rounded-lg;

  .search-icon {
    @apply text-slate-400;
  }

  .search-input {
    @apply flex-1 bg-transparent border-none text-sm focus:outline-none
           placeholder:text-slate-400;
  }
}

.icons-grid {
  @apply overflow-y-auto max-h-[320px];
}

.icon-row {
  @apply grid grid-cols-6 gap-1 mb-1;
}

.icon-button {
  @apply flex flex-col items-center p-2 rounded-lg
         hover:bg-slate-50 dark:hover:bg-slate-700
         transition-colors;

  &.selected {
    @apply bg-primary-50 dark:bg-primary-900;
  }

  .icon-label {
    @apply text-[10px] text-slate-500 dark:text-slate-400 mt-1 truncate max-w-full;
  }
}

.fade-enter-active,
.fade-leave-active {
  @apply transition-all duration-200;
}

.fade-enter-from,
.fade-leave-to {
  @apply opacity-0 scale-95;
}

.fade-enter-to,
.fade-leave-from {
  @apply opacity-100 scale-100;
}
</style>
