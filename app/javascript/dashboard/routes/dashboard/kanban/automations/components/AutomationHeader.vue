<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  name: {
    type: String,
    default: '',
  },
  active: {
    type: Boolean,
    default: true,
  },
  isSaving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:name', 'update:active', 'save', 'cancel']);

const { t } = useI18n();
const localName = ref(props.name);
const localActive = ref(props.active);

watch(
  () => props.name,
  newValue => {
    localName.value = newValue;
  }
);

watch(
  () => props.active,
  newValue => {
    localActive.value = newValue;
  }
);

const handleNameChange = () => {
  emit('update:name', localName.value);
};

const handleActiveChange = () => {
  emit('update:active', localActive.value);
};
</script>

<template>
  <div class="automation-header">
    <div class="header-left">
      <button class="back-button" @click="$emit('cancel')">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M19 12H5M12 19l-7-7 7-7"></path>
        </svg>
      </button>
      <div class="title-container">
        <input
          v-model="localName"
          class="automation-name"
          :placeholder="t('KANBAN.AUTOMATIONS.FLOW_EDITOR.NAME_PLACEHOLDER')"
          @input="handleNameChange"
        />
      </div>
    </div>

    <div class="header-actions">
      <div class="status-toggle">
        <label class="toggle-label">
          {{ t('KANBAN.AUTOMATIONS.FLOW_EDITOR.ACTIVE') }}
          <input
            type="checkbox"
            v-model="localActive"
            @change="handleActiveChange"
          />
          <span class="toggle-switch"></span>
        </label>
      </div>

      <button class="save-button" :disabled="isSaving" @click="$emit('save')">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path
            d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"
          ></path>
          <polyline points="17 21 17 13 7 13 7 21"></polyline>
          <polyline points="7 3 7 8 15 8"></polyline>
        </svg>
        {{ t('KANBAN.AUTOMATIONS.FLOW_EDITOR.SAVE') }}
      </button>

      <button class="cancel-button" @click="$emit('cancel')">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <line x1="18" y1="6" x2="6" y2="18"></line>
          <line x1="6" y1="6" x2="18" y2="18"></line>
        </svg>
        {{ t('KANBAN.AUTOMATIONS.FLOW_EDITOR.CANCEL') }}
      </button>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.automation-header {
  @apply flex justify-between items-center p-4 border-b border-slate-200 dark:border-slate-700;
  height: 64px;
  background-color: white;

  .header-left {
    @apply flex items-center gap-3;
  }

  .back-button {
    @apply p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 
      text-slate-700 dark:text-slate-300 transition-colors;
  }

  .title-container {
    @apply flex flex-col;
  }

  .automation-name {
    @apply text-xl font-medium text-slate-800 dark:text-slate-100
      focus:outline-none focus:ring-2 focus:ring-woot-500/30
      px-1 py-0.5 rounded-md;
    min-width: 200px;
  }

  .header-actions {
    @apply flex items-center gap-3;
  }

  .status-toggle {
    @apply flex items-center gap-2;

    .toggle-label {
      @apply flex items-center gap-2 text-sm font-medium
        text-slate-700 dark:text-slate-300 cursor-pointer;
    }

    input[type='checkbox'] {
      @apply hidden;

      &:checked + .toggle-switch {
        @apply bg-green-500;
      }

      &:checked + .toggle-switch:before {
        transform: translateX(18px);
      }
    }

    .toggle-switch {
      @apply relative inline-block w-10 h-5 bg-slate-300 dark:bg-slate-700
        rounded-full transition-colors;

      &:before {
        content: '';
        @apply absolute left-1 top-1 w-3 h-3 bg-white rounded-full
          transition-transform;
      }
    }
  }

  .save-button {
    @apply flex items-center gap-1 px-3 py-1.5 rounded-md
      bg-woot-500 text-white text-sm font-medium
      hover:bg-woot-600 transition-colors;

    &:disabled {
      @apply opacity-50 cursor-not-allowed;
    }
  }

  .cancel-button {
    @apply flex items-center gap-1 px-3 py-1.5 rounded-md
      bg-slate-100 dark:bg-slate-800 
      text-slate-700 dark:text-slate-300 text-sm font-medium
      hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors;
  }

  .icon {
    @apply flex items-center justify-center;

    .material-icons {
      @apply text-base leading-none;
      font-weight: normal;
      font-style: normal;
    }
  }

  .save-button,
  .cancel-button,
  .back-button {
    @apply flex items-center gap-1;

    .icon {
      @apply flex items-center justify-center;
    }
  }
}
</style>
