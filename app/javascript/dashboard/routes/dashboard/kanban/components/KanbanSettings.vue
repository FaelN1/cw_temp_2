<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '../../../../components/Modal.vue';
import webhookService from '../../../../services/kanban/webhookService';

const { t } = useI18n();
const emit = defineEmits(['close']);

const props = defineProps({
  show: {
    type: Boolean,
    required: true,
  },
});

const globalWebhookEnabled = ref(false);
const webhookUrl = ref('');

onMounted(() => {
  // Carrega as configurações salvas
  globalWebhookEnabled.value =
    localStorage.getItem('kanban_webhook_enabled') === 'true';
  webhookUrl.value = localStorage.getItem('kanban_webhook_url') || '';
});

const handleClose = () => {
  emit('close');
};

const handleSave = () => {
  webhookService.setWebhookConfig({
    url: webhookUrl.value,
    enabled: globalWebhookEnabled.value,
  });
  handleClose();
};
</script>

<template>
  <Modal :show="show" :on-close="handleClose" size="medium">
    <div class="settings-modal">
      <header class="settings-header">
        <h3 class="text-lg font-medium">
          {{ t('KANBAN.SETTINGS.TITLE') }}
        </h3>
      </header>

      <div class="settings-content">
        <div class="setting-item">
          <label class="flex items-center space-x-2 cursor-pointer">
            <input
              v-model="globalWebhookEnabled"
              type="checkbox"
              class="form-checkbox"
            />
            <span>{{ t('KANBAN.SETTINGS.ENABLE_GLOBAL_WEBHOOK') }}</span>
          </label>
        </div>

        <div v-if="globalWebhookEnabled" class="setting-item mt-4">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
          >
            {{ t('KANBAN.SETTINGS.WEBHOOK_URL') }}
          </label>
          <input
            v-model="webhookUrl"
            type="url"
            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-1 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-700 dark:border-slate-600"
            :placeholder="t('KANBAN.SETTINGS.WEBHOOK_URL_PLACEHOLDER')"
            required
          />
        </div>
      </div>

      <footer class="settings-footer">
        <woot-button variant="clear" size="small" @click="handleClose">
          {{ t('KANBAN.CANCEL') }}
        </woot-button>
        <woot-button variant="primary" size="small" @click="handleSave">
          {{ t('KANBAN.SAVE') }}
        </woot-button>
      </footer>
    </div>
  </Modal>
</template>

<style lang="scss" scoped>
.settings-modal {
  @apply flex flex-col;

  .settings-header {
    @apply p-4 border-b border-slate-100;
  }

  .settings-content {
    @apply p-4 space-y-4;

    .setting-item {
      @apply flex items-center;
    }
  }

  .settings-footer {
    @apply p-4 border-t border-slate-100 flex justify-end space-x-2;
  }
}
</style>
