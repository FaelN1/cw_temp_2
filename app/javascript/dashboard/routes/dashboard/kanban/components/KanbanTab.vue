<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import KanbanAPI from '../../../../api/kanban';
import KanbanColumn from './KanbanColumn.vue';
import KanbanHeader from './KanbanHeader.vue';
import { useStore } from 'vuex';
import KanbanItemForm from './KanbanItemForm.vue';
import Modal from '../../../../components/Modal.vue';
import KanbanItemDetails from './KanbanItemDetails.vue';
import KanbanFilter from './KanbanFilter.vue';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  currentView: {
    type: String,
    default: 'kanban',
  },
  kanbanItems: {
    type: Array,
    required: true,
  },
  isLoading: {
    type: Boolean,
    required: true,
  },
});

const emit = defineEmits([
  'switchView',
  'itemsUpdated',
  'search',
  'forceUpdate',
  'itemClick',
]);
const { t } = useI18n();
const store = useStore();

// Estado
const error = computed(() => store.state.kanban.error);
const columns = ref([]);
const showAddModal = ref(false);
const selectedColumn = ref(null);
const selectedFunnel = computed(
  () => store.getters['funnel/getSelectedFunnel']
);
const showDeleteModal = ref(false);
const itemToDelete = ref(null);
const showEditModal = ref(false);
const itemToEdit = ref(null);
const showDetailsModal = ref(false);
const itemToShow = ref(null);
const activeFilters = ref(null);
const showFilterModal = ref(false);
const filteredResults = ref({ total: 0, stages: {} });
const mountKey = ref(0);
const isUpdating = ref(false);
const searchQuery = ref('');

// Funções
const updateColumns = () => {
  // Obter os estágios do funil selecionado
  const funnel = store.getters['funnel/getSelectedFunnel'];
  if (!funnel?.stages) return;

  console.log('[ORDENAÇÃO] Estágios do funil:', funnel.stages);

  // Transformar em array mantendo a ordem original do objeto
  const stagesArray = Object.entries(funnel.stages).map(([id, stage]) => ({
    id,
    title: stage.name,
    color: stage.color,
    description: stage.description,
    position: parseInt(stage.position, 10) || 0,
    items: props.kanbanItems.filter(item => item.funnel_stage === id),
  }));

  console.log(
    '[ORDENAÇÃO] Array de estágios (antes de ordenar):',
    stagesArray.map(s => `${s.title} (${s.position})`)
  );

  // Ordenar os estágios por posição
  stagesArray.sort((a, b) => a.position - b.position);

  console.log(
    '[ORDENAÇÃO] Array de estágios (após ordenação):',
    stagesArray.map(s => `${s.title} (${s.position})`)
  );

  // Atualizar as colunas com a ordem ordenada por posição
  columns.value = stagesArray;
};

// Atualizar colunas quando os itens mudarem
watch(
  () => props.kanbanItems,
  () => {
    // Atualizar colunas quando os itens mudam
    updateColumns();
  },
  { deep: true } // Adicionar deep:true para detectar mudanças profundas
);

// Atualizar colunas quando o funil mudar
watch(
  selectedFunnel,
  newFunnel => {
    if (!newFunnel) return;

    console.log('[ORDENAÇÃO-FUNIL] Novo funil selecionado:', newFunnel.name);

    // Garantir que as posições sejam números inteiros
    if (newFunnel.stages) {
      Object.values(newFunnel.stages).forEach(stage => {
        stage.position = parseInt(stage.position, 10) || 0;
      });
    }

    // Atualizar colunas com a ordenação correta
    updateColumns();
  },
  { immediate: true }
);

const handleAdd = columnId => {
  selectedColumn.value = columns.value.find(col => col.id === columnId);
  showAddModal.value = true;
};

const handleDelete = async itemToDeleteParam => {
  try {
    isUpdating.value = true;
    await store.dispatch('kanban/deleteKanbanItem', itemToDeleteParam.id);
    showDeleteModal.value = false;
    itemToDelete.value = null;
  } catch (err) {
    emitter.emit('newToastMessage', {
      message: err.response?.data?.message || t('KANBAN.ERROR_DELETING_ITEM'),
      action: { type: 'error' },
    });
  } finally {
    isUpdating.value = false;
  }
};

const handleDrop = async ({ itemId, columnId }) => {
  if (!itemId || !columnId) return;

  try {
    isUpdating.value = true;

    // Chamada ao store - o store já gerencia a atualização dos itens
    await store.dispatch('kanban/moveItemToStage', {
      itemId: parseInt(itemId, 10),
      columnId,
    });

    // Apenas forçar atualização visual das colunas sem buscar novos dados
    nextTick(() => {
      updateColumns();
    });
  } catch (err) {
    emitter.emit('newToastMessage', {
      message: err.response?.data?.message || t('KANBAN.ERROR_MOVING_ITEM'),
      action: { type: 'error' },
    });
  } finally {
    isUpdating.value = false;
  }
};

const handleSettings = () => {
  // TODO: Implementar configurações do Kanban
  emitter.emit('newToastMessage', {
    message: t('KANBAN.SETTINGS_NOT_IMPLEMENTED'),
    action: { type: 'info' },
  });
};

const handleItemCreated = async item => {
  if (!item) return;
  showAddModal.value = false;
  selectedColumn.value = null;
};

const handleSearch = query => {
  searchQuery.value = query;
};

const handleFilterClose = () => {
  showFilterModal.value = false;

  // Se não houver filtros ativos, recarregar os itens
  if (!activeFilters.value) {
    store.dispatch('kanban/fetchKanbanItems');
  }
};

const handleFilter = filters => {
  // Verificação defensiva: se filters for null ou undefined, use um objeto vazio
  activeFilters.value = filters || {};
};

const handleEdit = item => {
  itemToEdit.value = item;
  showEditModal.value = true;
};

const handleItemClick = item => {
  emit('itemClick', item);
};

const handleEditFromDetails = item => {
  showDetailsModal.value = false;
  handleEdit(item);
};

const handleDetailsUpdate = () => {
  // No need to emit 'forceUpdate' here
};

const handleItemEdited = async item => {
  if (!item) return;
  showEditModal.value = false;
  itemToEdit.value = null;
};

// Computed
const userHasAccess = computed(() => {
  const currentUser = store.getters.getCurrentUser;
  const currentFunnel = store.getters['funnel/getSelectedFunnel'];

  if (!currentFunnel || !currentUser) return false;
  if (currentUser.role === 'administrator') return true;

  return currentFunnel.settings?.agents?.some(
    agent => agent.id === currentUser.id
  );
});

// Computed para filtrar os itens baseado na busca e nos filtros
const filteredColumns = computed(() => {
  // Criar uma cópia exata para manter a mesma ordem
  let result = [...columns.value];
  console.log(
    '[ORDENAÇÃO-FILTER] Colunas originais:',
    result.map(col => `${col.title} (posição: ${col.position})`)
  );

  // Aplicar filtros sem alterar a ordem
  if (searchQuery.value) {
    result = result.map(column => ({
      ...column,
      items: column.items.filter(item => {
        const searchTerm = searchQuery.value.toLowerCase();
        const title = (item.item_details?.title || '').toLowerCase();
        const description = (
          item.item_details?.description || ''
        ).toLowerCase();
        return title.includes(searchTerm) || description.includes(searchTerm);
      }),
    }));
  }

  // Aplicar filtros ativos
  if (activeFilters.value) {
    result = result.map(column => ({
      ...column,
      items: column.items.filter(item => {
        // Filtro por prioridade - verificar se priority existe e não é vazio
        if (
          activeFilters.value.priority &&
          activeFilters.value.priority.length > 0
        ) {
          const itemPriority = item.item_details?.priority || 'none';
          if (!activeFilters.value.priority.includes(itemPriority)) {
            return false;
          }
        }

        // Filtro por valor - Corrigido para nova estrutura
        if (activeFilters.value.value_min || activeFilters.value.value_max) {
          const itemValue = parseFloat(item.item_details?.value) || 0;
          if (
            activeFilters.value.value_min &&
            itemValue < parseFloat(activeFilters.value.value_min)
          ) {
            return false;
          }
          if (
            activeFilters.value.value_max &&
            itemValue > parseFloat(activeFilters.value.value_max)
          ) {
            return false;
          }
        }

        // Filtro por agente - Verificação mais segura
        if (activeFilters.value.agent_id) {
          // Verificar especificamente no item_details.agent_id
          const agentId = parseInt(activeFilters.value.agent_id, 10);
          if (item.item_details?.agent_id !== agentId) {
            return false;
          }
        }

        // Filtro por data - também precisa ser ajustado
        if (activeFilters.value.date_start || activeFilters.value.date_end) {
          const itemDate = new Date(item.created_at);
          if (activeFilters.value.date_start) {
            const startDate = new Date(activeFilters.value.date_start);
            if (itemDate < startDate) {
              return false;
            }
          }
          if (activeFilters.value.date_end) {
            const endDate = new Date(activeFilters.value.date_end);
            endDate.setHours(23, 59, 59);
            if (itemDate > endDate) {
              return false;
            }
          }
        }

        return true;
      }),
    }));
  }

  // Ordenar explicitamente por posição antes de retornar, garantindo ordem correta
  result.sort((a, b) => {
    const posA = parseInt(a.position, 10) || 0;
    const posB = parseInt(b.position, 10) || 0;
    return posA - posB;
  });

  console.log(
    '[ORDENAÇÃO-FILTER] Colunas após ordenação final:',
    result.map(col => `${col.title} (posição: ${col.position})`)
  );

  return result;
});

// Computed para calcular os resultados da busca
const searchResults = computed(() => {
  if (!searchQuery.value) return { total: 0, stages: {} };

  const results = {
    total: 0,
    stages: {},
  };

  filteredColumns.value.forEach(column => {
    if (column.items.length > 0) {
      results.stages[column.title] = column.items.length;
      results.total += column.items.length;
    }
  });

  return results;
});

// Computed para depuração da ordenação final das colunas
const columnsOrderDebug = computed(() => {
  // Log para debugar a ordem final das colunas
  console.log(
    '[ORDENAÇÃO-RENDER] Colunas filtradas na renderização:',
    filteredColumns.value.map(col => `${col.title} (posição: ${col.position})`)
  );
  return true;
});
</script>

<template>
  <div :key="mountKey" class="flex flex-col h-full bg-white dark:bg-slate-900">
    <KanbanHeader
      :current-view="currentView"
      :current-stage="selectedColumn?.id"
      :search-results="searchResults"
      :columns="filteredColumns"
      :active-filters="activeFilters"
      :kanban-items="kanbanItems"
      @filter="showFilterModal = true"
      @settings="handleSettings"
      @itemCreated="handleItemCreated"
      @itemsUpdated="() => store.dispatch('kanban/fetchKanbanItems')"
      @search="handleSearch"
      @switchView="view => emit('switchView', view)"
    />

    <div v-if="isLoading" class="flex justify-center items-center flex-1">
      <span class="loading-spinner" />
    </div>

    <div
      v-else-if="error"
      class="flex justify-center items-center flex-1 text-ruby-500"
    >
      {{ error }}
    </div>

    <div
      v-else-if="!userHasAccess"
      class="flex flex-col items-center justify-center flex-1 p-8 text-center"
    >
      <div class="w-16 h-16 mb-4 text-slate-400">
        <fluent-icon icon="lock-closed" size="64" />
      </div>
      <h3 class="text-xl font-medium text-slate-700 dark:text-slate-300 mb-2">
        {{ t('KANBAN.ACCESS_RESTRICTED') }}
      </h3>
      <p class="text-sm text-slate-600 dark:text-slate-400 max-w-md">
        {{ t('KANBAN.ACCESS_RESTRICTED_MESSAGE') }}
      </p>
    </div>

    <div v-else class="flex-1 overflow-x-auto kanban-columns">
      <div
        v-if="isUpdating"
        class="absolute top-2 right-2 flex items-center text-sm text-slate-500"
      >
        <span class="loading-spinner-small mr-2" />
        {{ t('KANBAN.UPDATING') }}
      </div>

      <div class="flex h-full p-4 space-x-4">
        <!-- Debug helper hidden -->
        <div v-if="columnsOrderDebug" class="hidden" />

        <KanbanColumn
          v-for="column in filteredColumns
            .slice()
            .sort((a, b) => a.position - b.position)"
          :key="column.id"
          :id="column.id"
          :title="column.title"
          :color="column.color"
          :items="column.items"
          :count="column.items.length"
          :total-columns="filteredColumns.length"
          @add="handleAdd"
          @edit="handleEdit"
          @delete="handleDelete"
          @drop="handleDrop"
          @item-click="handleItemClick"
        />
      </div>
    </div>

    <!-- Modais -->
    <Modal
      v-model:show="showAddModal"
      size="full-width"
      :on-close="() => (showAddModal = false)"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium">
          {{ t('KANBAN.ADD_ITEM') }}
        </h3>
        <KanbanItemForm
          v-if="selectedColumn && selectedFunnel"
          :funnel-id="selectedFunnel.id"
          :stage="selectedColumn.id"
          :position="selectedColumn.position"
          @saved="handleItemCreated"
          @close="showAddModal = false"
        />
        <div v-else class="text-center text-red-500">
          {{ t('KANBAN.ERRORS.NO_FUNNEL_SELECTED') }}
        </div>
      </div>
    </Modal>

    <Modal
      v-model:show="showDeleteModal"
      :on-close="
        () => {
          showDeleteModal = false;
          itemToDelete = null;
        }
      "
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.DELETE_CONFIRMATION.TITLE') }}
        </h3>
        <p class="text-sm text-slate-600 dark:text-slate-400 mb-6">
          {{
            t('KANBAN.DELETE_CONFIRMATION.MESSAGE', {
              item: itemToDelete?.title,
            })
          }}
        </p>
        <div class="flex justify-end space-x-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click="showDeleteModal = false"
          >
            {{ t('KANBAN.CANCEL') }}
          </woot-button>
          <woot-button
            variant="solid"
            color-scheme="alert"
            @click="handleDelete(itemToDelete)"
          >
            {{ t('KANBAN.DELETE') }}
          </woot-button>
        </div>
      </div>
    </Modal>

    <Modal
      v-model:show="showEditModal"
      size="full-width"
      :on-close="
        () => {
          showEditModal = false;
          itemToEdit = null;
        }
      "
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.FORM.EDIT_ITEM') }}
        </h3>
        <KanbanItemForm
          v-if="itemToEdit && selectedFunnel"
          :funnel-id="selectedFunnel.id"
          :stage="itemToEdit.funnel_stage"
          :position="itemToEdit.position"
          :initial-data="itemToEdit"
          is-editing
          @saved="handleItemEdited"
          @close="showEditModal = false"
        />
      </div>
    </Modal>

    <Modal
      v-model:show="showDetailsModal"
      size="full-width"
      :on-close="
        () => {
          showDetailsModal = false;
          itemToShow = null;
          handleDetailsUpdate();
        }
      "
    >
      <KanbanItemDetails
        v-if="itemToShow"
        :item="itemToShow"
        @close="
          () => {
            showDetailsModal = false;
            itemToShow = null;
            handleDetailsUpdate();
          }
        "
        @edit="handleEditFromDetails"
        @item-updated="handleDetailsUpdate"
      />
    </Modal>

    <KanbanFilter
      :show="showFilterModal"
      :columns="columns"
      :filtered-results="filteredResults"
      :current-funnel="store.getters['funnel/getSelectedFunnel']"
      @close="handleFilterClose"
      @apply="handleFilter"
    />
  </div>
</template>

<style scoped>
.flex-1 {
  min-height: 0;
}

.kanban-columns {
  scrollbar-width: thin;
  scrollbar-color: var(--color-woot) var(--color-background-light);

  &::-webkit-scrollbar {
    height: 8px;
    background: transparent;
  }

  &::-webkit-scrollbar-track {
    background: var(--color-background-light);
    border-radius: 4px;
  }

  &::-webkit-scrollbar-thumb {
    background: var(--color-woot);
    border-radius: 4px;
    opacity: 0.8;

    &:hover {
      opacity: 1;
    }
  }
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid #f3f3f3;
  border-top: 3px solid #3498db;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

.loading-spinner-small {
  width: 16px;
  height: 16px;
  border: 2px solid #f3f3f3;
  border-top: 2px solid #3498db;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

:root {
  --color-background-light: #f1f5f9;
}

.dark {
  --color-background-light: #1e293b;
}
</style>
