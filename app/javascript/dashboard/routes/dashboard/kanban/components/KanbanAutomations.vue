<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import Modal from '../../../../components/Modal.vue';
import AutomationForm from './AutomationForm.vue';
import KanbanAPI from '../../../../api/kanban';
import { emitter } from 'shared/helpers/mitt';

const emit = defineEmits(['switchView']);

const { t } = useI18n();
const store = useStore();

const automations = ref([]);
const loading = ref(true);
const showAddModal = ref(false);
const showEditModal = ref(false);
const showDeleteModal = ref(false);
const selectedAutomation = ref(null);
const saving = ref(false);
const funnels = ref([]);
const loadingFunnels = ref(false);

const userIsAdmin = computed(() => {
  const currentUser = store.getters.getCurrentUser;
  return currentUser?.role === 'administrator';
});

const columns = computed(() => {
  // Obter todas as colunas de todos os funis
  const allColumns = [];
  funnels.value.forEach(funnel => {
    if (funnel.stages) {
      Object.entries(funnel.stages).forEach(([id, stage]) => {
        allColumns.push({
          id,
          title: `${funnel.name} - ${stage.name}`,
          funnelId: funnel.id,
          color: stage.color,
        });
      });
    }
  });
  return allColumns;
});

const fetchFunnels = async () => {
  loadingFunnels.value = true;
  try {
    // Obter funis do store
    const funnelsData = store.getters['funnel/getFunnels'];
    if (funnelsData && funnelsData.length > 0) {
      funnels.value = funnelsData;
    } else {
      // Se não estiver no store, buscar da API
      await store.dispatch('funnel/fetchFunnels');
      funnels.value = store.getters['funnel/getFunnels'] || [];
    }
  } catch (error) {
    emitter.emit('newToastMessage', {
      message: t('KANBAN.FUNNELS.FETCH_ERROR'),
      action: { type: 'error' },
    });
  } finally {
    loadingFunnels.value = false;
  }
};

const fetchAutomations = async () => {
  loading.value = true;
  try {
    const { data } = await KanbanAPI.getAutomations();
    automations.value = data?.length
      ? data.map(automation => ({
          ...automation,
          trigger: automation.trigger || {
            type: 'item_created',
            column: 'all',
          },
          conditions: automation.conditions || [],
          actions: automation.actions || [],
        }))
      : [];
  } catch (error) {
    automations.value = [];
    emitter.emit('newToastMessage', {
      message: t('KANBAN.AUTOMATIONS.FETCH_ERROR'),
      action: { type: 'error' },
    });
  } finally {
    loading.value = false;
  }
};

// Carregar dados iniciais
onMounted(async () => {
  await Promise.all([fetchFunnels(), fetchAutomations()]);
});

const handleAdd = () => {
  emit('switchView', 'automation-editor');
};

const handleEdit = automation => {
  store.dispatch('automationEditor/setCurrentAutomation', automation);
  emit('switchView', 'automation-editor');
};

const handleDelete = automation => {
  selectedAutomation.value = automation;
  showDeleteModal.value = true;
};

const confirmDelete = async () => {
  try {
    saving.value = true;
    await KanbanAPI.deleteAutomation(selectedAutomation.value.id);
    automations.value = automations.value.filter(
      a => a.id !== selectedAutomation.value.id
    );
    emitter.emit('newToastMessage', {
      message: t('KANBAN.AUTOMATIONS.DELETE_SUCCESS'),
      action: { type: 'success' },
    });
    showDeleteModal.value = false;
    selectedAutomation.value = null;
  } catch (error) {
    emitter.emit('newToastMessage', {
      message: t('KANBAN.AUTOMATIONS.DELETE_ERROR'),
      action: { type: 'error' },
    });
  } finally {
    saving.value = false;
  }
};

const handleSave = async automation => {
  saving.value = true;
  try {
    // Garantir que os dados estejam estruturados corretamente
    const formattedAutomation = {
      ...automation,
      trigger: automation.trigger || { type: 'item_created', column: 'all' },
      conditions: automation.conditions || [],
      actions: automation.actions || [],
    };

    if (automation.id) {
      // Editar existente
      await KanbanAPI.updateAutomation(automation.id, formattedAutomation);
      const index = automations.value.findIndex(a => a.id === automation.id);
      if (index !== -1) {
        automations.value[index] = formattedAutomation;
      }
      emitter.emit('newToastMessage', {
        message: t('KANBAN.AUTOMATIONS.UPDATE_SUCCESS'),
        action: { type: 'success' },
      });
      showEditModal.value = false;
    } else {
      // Adicionar novo
      const { data } = await KanbanAPI.createAutomation(formattedAutomation);
      automations.value.push(data);
      emitter.emit('newToastMessage', {
        message: t('KANBAN.AUTOMATIONS.CREATE_SUCCESS'),
        action: { type: 'success' },
      });
      showAddModal.value = false;
    }
  } catch (error) {
    emitter.emit('newToastMessage', {
      message: automation.id
        ? t('KANBAN.AUTOMATIONS.UPDATE_ERROR')
        : t('KANBAN.AUTOMATIONS.CREATE_ERROR'),
      action: { type: 'error' },
    });
  } finally {
    saving.value = false;
  }
};

const getColumnName = columnId => {
  if (!columnId) return '';
  if (columnId === 'all')
    return t('KANBAN.AUTOMATIONS.FORM.TRIGGER.COLUMN.ALL');
  const column = columns.value.find(c => c.id === columnId);
  return column ? column.title : columnId;
};

const getTriggerTypeLabel = type => {
  if (!type) return '';
  return t(`KANBAN.AUTOMATIONS.FORM.TRIGGER.TYPE.${type.toUpperCase()}`);
};

const getActionTypeLabel = type => {
  if (!type) return '';
  return t(`KANBAN.AUTOMATIONS.FORM.ACTIONS.TYPE.${type.toUpperCase()}`);
};

const handleBackToKanban = () => {
  emit('switchView', 'kanban');
};
</script>

<template>
  <div
    class="automations-container flex flex-col h-full w-full bg-white dark:bg-slate-900"
  >
    <header class="automations-header">
      <div class="header-left">
        <button class="back-button" @click="handleBackToKanban">
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
        <h1 class="title">{{ t('KANBAN.AUTOMATIONS.TITLE') }}</h1>
      </div>
      <div class="header-right">
        <woot-button
          v-if="userIsAdmin"
          variant="smooth"
          color-scheme="primary"
          size="small"
          @click="handleAdd"
        >
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
            <path d="M12 5v14M5 12h14"></path>
          </svg>
          {{ t('KANBAN.AUTOMATIONS.ADD') }}
        </woot-button>
      </div>
    </header>

    <div class="automations-content">
      <p class="description">
        {{ t('KANBAN.AUTOMATIONS.DESCRIPTION') }}
      </p>

      <div v-if="loading || loadingFunnels" class="loading-container">
        <div class="loading-spinner" />
        <p>{{ t('KANBAN.AUTOMATIONS.LOADING') }}</p>
      </div>

      <div v-else-if="!automations.length" class="empty-state">
        <div class="empty-icon">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="48"
            height="48"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <rect x="3" y="11" width="18" height="10" rx="2" />
            <circle cx="12" cy="5" r="2" />
            <path d="M12 7v4" />
            <line x1="8" y1="16" x2="8" y2="16" />
            <line x1="16" y1="16" x2="16" y2="16" />
          </svg>
        </div>
        <h3>{{ t('KANBAN.AUTOMATIONS.EMPTY_TITLE') }}</h3>
        <p>
          {{ t('KANBAN.AUTOMATIONS.CREATE_FIRST') }}
        </p>
        <woot-button
          v-if="userIsAdmin"
          variant="smooth"
          color-scheme="primary"
          class="mt-4"
          @click="handleAdd"
        >
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
            class="mr-1"
          >
            <path d="M12 5v14M5 12h14"></path>
          </svg>
          {{ t('KANBAN.AUTOMATIONS.ADD') }}
        </woot-button>
      </div>

      <div v-else class="automations-list">
        <div
          v-for="automation in automations"
          :key="automation.id"
          class="automation-card"
          :class="{ inactive: !automation.active }"
        >
          <div class="card-header">
            <div class="card-title">
              <h3>{{ automation.name }}</h3>
              <span v-if="automation.active" class="status active">
                {{ t('ACTIVE') }}
              </span>
              <span v-else class="status inactive">
                {{ t('INACTIVE') }}
              </span>
            </div>
            <div class="card-actions">
              <button class="action-button" @click="handleEdit(automation)">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"></path>
                </svg>
              </button>
              <button class="action-button" @click="handleDelete(automation)">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M3 6h18"></path>
                  <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"></path>
                  <path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                </svg>
              </button>
            </div>
          </div>

          <p class="card-description">{{ automation.description }}</p>

          <div class="card-details">
            <div class="detail-section">
              <h4>{{ t('KANBAN.AUTOMATIONS.FORM.TRIGGER.TITLE') }}</h4>
              <div class="detail-item">
                <span class="detail-label"
                  >{{ t('KANBAN.AUTOMATIONS.FORM.TRIGGER.TYPE.LABEL') }}:</span
                >
                <span class="detail-value">{{
                  getTriggerTypeLabel(automation.trigger?.type)
                }}</span>
              </div>
              <div class="detail-item">
                <span class="detail-label"
                  >{{
                    t('KANBAN.AUTOMATIONS.FORM.TRIGGER.COLUMN.LABEL')
                  }}:</span
                >
                <span class="detail-value">{{
                  getColumnName(automation.trigger?.column)
                }}</span>
              </div>
              <div
                v-if="automation.trigger?.inactivity_period"
                class="detail-item"
              >
                <span class="detail-label"
                  >{{
                    t(
                      'KANBAN.AUTOMATIONS.FORM.TRIGGER.INACTIVITY_PERIOD.LABEL'
                    )
                  }}:</span
                >
                <span class="detail-value"
                  >{{ automation.trigger.inactivity_period }}
                  {{
                    t('KANBAN.AUTOMATIONS.FORM.TRIGGER.INACTIVITY_PERIOD.DAYS')
                  }}</span
                >
              </div>
            </div>

            <div
              v-if="automation.conditions?.length > 0"
              class="detail-section"
            >
              <h4>{{ t('KANBAN.AUTOMATIONS.FORM.CONDITIONS.TITLE') }}</h4>
              <div
                v-for="(condition, index) in automation.conditions"
                :key="index"
                class="detail-item"
              >
                <span class="detail-value" v-if="condition?.field">
                  {{
                    t(
                      `KANBAN.AUTOMATIONS.FORM.CONDITIONS.FIELD.${condition.field.toUpperCase()}`
                    )
                  }}
                  {{
                    condition.operator
                      ? t(
                          `KANBAN.AUTOMATIONS.FORM.CONDITIONS.OPERATOR.${condition.operator.toUpperCase()}`
                        )
                      : ''
                  }}
                  {{ condition.value || '' }}
                </span>
              </div>
            </div>

            <div class="detail-section">
              <h4>{{ t('KANBAN.AUTOMATIONS.FORM.ACTIONS.TITLE') }}</h4>
              <div
                v-for="(action, index) in automation.actions || []"
                :key="index"
                class="detail-item"
              >
                <span class="detail-value" v-if="action?.type">
                  {{ getActionTypeLabel(action.type) }}
                  <template
                    v-if="action.type === 'move_to_column' && action.column"
                  >
                    {{ t('KANBAN.AUTOMATIONS.TRIGGER_SYMBOLS.MOVE_TO') }}
                    {{ getColumnName(action.column) }}
                  </template>
                  <template
                    v-else-if="
                      action.type === 'send_notification' && action.message
                    "
                  >
                    {{ t('KANBAN.AUTOMATIONS.TRIGGER_SYMBOLS.NOTIFICATION') }}
                    {{ action.message }}
                  </template>
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal para adicionar automação -->
    <Modal
      v-if="showAddModal"
      :show="showAddModal"
      :on-close="() => (showAddModal = false)"
      size="large"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-6">
          {{ t('KANBAN.AUTOMATIONS.ADD') }}
        </h3>
        <AutomationForm
          :columns="columns"
          :funnels="funnels"
          @save="handleSave"
          @cancel="showAddModal = false"
        />
      </div>
    </Modal>

    <!-- Modal para editar automação -->
    <Modal
      v-if="showEditModal"
      :show="showEditModal"
      :on-close="() => (showEditModal = false)"
      size="large"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-6">
          {{ t('KANBAN.AUTOMATIONS.EDIT.TITLE') }}
        </h3>
        <AutomationForm
          v-if="selectedAutomation"
          :automation="selectedAutomation"
          :columns="columns"
          :funnels="funnels"
          @save="handleSave"
          @cancel="showEditModal = false"
        />
      </div>
    </Modal>

    <!-- Modal para confirmar exclusão -->
    <Modal
      v-if="showDeleteModal"
      :show="showDeleteModal"
      :on-close="() => (showDeleteModal = false)"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.AUTOMATIONS.DELETE.TITLE') }}
        </h3>
        <p class="mb-6">
          {{
            t('KANBAN.AUTOMATIONS.DELETE.DESCRIPTION', {
              name: selectedAutomation?.name,
            })
          }}
        </p>
        <div class="flex justify-end space-x-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click="showDeleteModal = false"
          >
            {{ t('KANBAN.AUTOMATIONS.DELETE.CANCEL') }}
          </woot-button>
          <woot-button
            variant="solid"
            color-scheme="alert"
            @click="confirmDelete"
            :loading="saving"
          >
            {{ t('KANBAN.AUTOMATIONS.DELETE.CONFIRM') }}
          </woot-button>
        </div>
      </div>
    </Modal>
  </div>
</template>

<style lang="scss" scoped>
.automations-container {
  overflow: hidden;
}

.automations-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--space-normal);
  border-bottom: 1px solid var(--color-border);
  @apply dark:border-slate-800;

  .header-left {
    display: flex;
    align-items: center;
    gap: var(--space-normal);
  }

  .back-button {
    @apply p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 
      text-slate-700 dark:text-slate-300 transition-colors;
  }

  .title {
    @apply text-xl font-medium text-slate-800 dark:text-slate-100;
  }
}

.automations-content {
  flex: 1;
  padding: var(--space-normal);
  overflow-y: auto;
  width: 100%;

  .description {
    @apply text-slate-600 dark:text-slate-400 mb-6;
  }
}

.loading-container {
  @apply flex flex-col items-center justify-center h-64 text-slate-600 dark:text-slate-400;

  .loading-spinner {
    @apply w-8 h-8 border-4 border-slate-200 border-t-woot-500 rounded-full animate-spin mb-4;
  }
}

.empty-state {
  @apply flex flex-col items-center justify-center h-64 text-center;

  .empty-icon {
    @apply text-slate-400 dark:text-slate-600 mb-4;
  }

  h3 {
    @apply text-lg font-medium text-slate-800 dark:text-slate-200 mb-2;
  }

  p {
    @apply text-slate-600 dark:text-slate-400 mb-6 max-w-md leading-relaxed;
  }
}

.automations-list {
  @apply grid gap-4;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  width: 100%;
  max-width: 100%;
}

.automation-card {
  @apply bg-white dark:bg-slate-800 rounded-lg shadow-sm border border-slate-200 
    dark:border-slate-700 overflow-hidden transition-all;

  &.inactive {
    @apply opacity-70;
  }

  .card-header {
    @apply flex justify-between items-start p-4 border-b border-slate-100 dark:border-slate-700;

    .card-title {
      @apply flex items-center gap-2;

      h3 {
        @apply text-base font-medium text-slate-800 dark:text-slate-200;
      }

      .status {
        @apply text-xs px-2 py-0.5 rounded-full;

        &.active {
          @apply bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200;
        }

        &.inactive {
          @apply bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400;
        }
      }
    }

    .card-actions {
      @apply flex gap-1;

      .action-button {
        @apply p-1.5 rounded-md hover:bg-slate-100 dark:hover:bg-slate-700 
          text-slate-500 dark:text-slate-400 transition-colors;
      }
    }
  }

  .card-description {
    @apply p-4 text-sm text-slate-600 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700;
  }

  .card-details {
    @apply p-4 text-sm;

    .detail-section {
      @apply mb-4 last:mb-0;

      h4 {
        @apply text-xs font-medium uppercase text-slate-500 dark:text-slate-400 mb-2;
      }

      .detail-item {
        @apply mb-1 last:mb-0 text-slate-700 dark:text-slate-300;

        .detail-label {
          @apply font-medium mr-1;
        }
      }
    }
  }
}

/* Responsividade para telas menores */
@media (max-width: 768px) {
  .automations-list {
    grid-template-columns: 1fr;
  }
}
</style>
