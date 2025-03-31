<script setup>
import { computed, ref, onMounted, onUnmounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import KanbanItem from './KanbanItem.vue';
import KanbanFilter from './KanbanFilter.vue';
import Modal from '../../../../components/Modal.vue';
import StageColorPicker from './StageColorPicker.vue';
import FunnelAPI from '../../../../api/funnel';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  id: {
    type: String,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  color: {
    type: String,
    default: 'orange',
  },
  items: {
    type: Array,
    required: true,
  },
  totalColumns: {
    type: Number,
    default: 0,
  },
  description: {
    type: String,
    default: '',
  },
});

const emit = defineEmits([
  'add',
  'edit',
  'delete',
  'drop',
  'itemClick',
  'itemsUpdated',
]);
const { t } = useI18n();

const store = useStore();

// Adicionar estado para filtros
const showFilterModal = ref(false);
const columnFilters = ref(null);
const showOptionsMenu = ref(false);
const columnSettings = ref({
  showWon: true,
  showLost: true,
  showAll: true,
  hideColumn: false,
});

const showEditStageModal = ref(false);
const editingStageForm = ref({
  name: '',
  color: '',
  description: '',
});

// Adicionar ref para controle do modal de ordenação
const showSortModal = ref(false);
const columnSort = ref({
  type: 'created_at', // default: data de criação
  direction: 'desc', // default: mais recentes primeiro
});

// Nova ref para controlar o estado de colapso em massa
const allItemsCollapsed = ref(false);

// Opções de ordenação disponíveis
const sortOptions = [
  { id: 'created_at', label: 'Data de Criação' },
  { id: 'title', label: 'Título' },
  { id: 'priority', label: 'Prioridade' },
  { id: 'value', label: 'Valor' },
];

// Carregar configurações do localStorage
onMounted(() => {
  const savedSettings = localStorage.getItem(
    `kanban_column_${props.id}_settings`
  );
  if (savedSettings) {
    columnSettings.value = JSON.parse(savedSettings);
  }

  const savedSort = localStorage.getItem(`kanban_column_${props.id}_sort`);
  if (savedSort) {
    columnSort.value = JSON.parse(savedSort);
  }
});

// Salvar configurações no localStorage
const saveColumnSettings = () => {
  localStorage.setItem(
    `kanban_column_${props.id}_settings`,
    JSON.stringify(columnSettings.value)
  );
};

// Salvar configurações de ordenação
const saveSortSettings = () => {
  localStorage.setItem(
    `kanban_column_${props.id}_sort`,
    JSON.stringify(columnSort.value)
  );
};

const filteredItems = computed(() => {
  if (columnSettings.value.hideColumn) {
    return [];
  }

  let items = props.items;

  // Aplicar filtros existentes
  if (columnFilters.value) {
    items = items.filter(item => {
      // Filtro por prioridade
      if (columnFilters.value.priority.length > 0) {
        const itemPriority = item.item_details?.priority || '';
        if (!columnFilters.value.priority.includes(itemPriority)) return false;
      }

      // Filtro por valor
      if (columnFilters.value.value.min || columnFilters.value.value.max) {
        const itemValue = parseFloat(item.item_details?.value) || 0;
        if (
          columnFilters.value.value.min &&
          itemValue < columnFilters.value.value.min
        )
          return false;
        if (
          columnFilters.value.value.max &&
          itemValue > columnFilters.value.value.max
        )
          return false;
      }

      // Filtro por agente
      if (columnFilters.value.agent_id) {
        const itemAgentId = item.assigned_agent_id;
        if (itemAgentId !== columnFilters.value.agent_id) return false;
      }

      // Filtro por data
      if (columnFilters.value.date.start || columnFilters.value.date.end) {
        const itemDate = new Date(item.created_at);
        if (columnFilters.value.date.start) {
          const startDate = new Date(columnFilters.value.date.start);
          if (itemDate < startDate) return false;
        }
        if (columnFilters.value.date.end) {
          const endDate = new Date(columnFilters.value.date.end);
          endDate.setHours(23, 59, 59);
          if (itemDate > endDate) return false;
        }
      }

      return true;
    });
  }

  // Aplicar filtros de status
  items = items.filter(item => {
    const status = item.item_details?.status;
    if (status === 'won' && !columnSettings.value.showWon) return false;
    if (status === 'lost' && !columnSettings.value.showLost) return false;
    return true;
  });

  // Aplicar ordenação
  return items.sort((a, b) => {
    const direction = columnSort.value.direction === 'asc' ? 1 : -1;

    switch (columnSort.value.type) {
      case 'title':
        return (
          direction *
          (a.item_details?.title || '').localeCompare(
            b.item_details?.title || ''
          )
        );

      case 'priority': {
        const priorityOrder = {
          urgent: 4,
          high: 3,
          medium: 2,
          low: 1,
          none: 0,
        };
        const priorityA = priorityOrder[a.item_details?.priority || 'none'];
        const priorityB = priorityOrder[b.item_details?.priority || 'none'];
        return direction * (priorityA - priorityB);
      }

      case 'value': {
        const valueA = parseFloat(a.item_details?.value) || 0;
        const valueB = parseFloat(b.item_details?.value) || 0;
        return direction * (valueA - valueB);
      }

      default: // created_at
        return direction * (new Date(a.created_at) - new Date(b.created_at));
    }
  });
});

// Resultados do filtro para exibir no modal
const filteredResults = computed(() => {
  if (!columnFilters.value) return { total: 0, stages: {} };

  const stages = {};
  stages[props.title] = filteredItems.value.length;

  return {
    total: filteredItems.value.length,
    stages,
  };
});

const columnTotal = computed(() => {
  return filteredItems.value.reduce((total, item) => {
    const value = parseFloat(item.item_details?.value) || 0;
    return total + value;
  }, 0);
});

const formattedTotal = computed(() => {
  if (!columnTotal.value) return '';
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(columnTotal.value);
});

const darkenColor = color => {
  const hex = color.replace('#', '');
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);

  const darkenAmount = 0.85;
  const dr = Math.floor(r * darkenAmount);
  const dg = Math.floor(g * darkenAmount);
  const db = Math.floor(b * darkenAmount);

  return `#${dr.toString(16).padStart(2, '0')}${dg.toString(16).padStart(2, '0')}${db.toString(16).padStart(2, '0')}`;
};

const textColor = computed(() =>
  props.color ? darkenColor(props.color) : '#CC6E00'
);

const columnStyle = computed(() => ({
  backgroundColor: props.color ? `${props.color}40` : '#f8fafc',
}));

const countStyle = computed(() => ({
  backgroundColor: props.color ? `${props.color}15` : '#FFF4E5',
  color: textColor.value,
}));

const handleDrop = event => {
  const itemID = event.dataTransfer.getData('text/plain');
  console.log(
    '[COLUMN-DROP-DEBUG] Item arrastado ID:',
    itemID,
    'para coluna:',
    props.id
  );

  if (itemID) {
    const numericId = parseInt(itemID, 10);
    console.log(
      '[COLUMN-DROP-DEBUG] ID convertido para número:',
      numericId,
      typeof numericId
    );

    // Garantir que o ID seja passado como número para o componente pai
    emit('drop', {
      itemId: numericId,
      columnId: props.id,
    });

    console.log(
      '[COLUMN-DROP-DEBUG] Evento drop emitido para o componente pai'
    );
  }
};

const handleDragOver = event => {
  event.preventDefault();
};

const columnWidth = computed(() => {
  if (props.totalColumns <= 5) {
    return {
      minWidth: '320px',
      maxWidth: `calc((100% - ${(props.totalColumns - 1) * 1}rem) / ${props.totalColumns})`,
      width: '100%',
    };
  }
  return {
    minWidth: '350px',
    maxWidth: '350px',
    width: '350px',
  };
});

// Funções para o filtro de coluna
const handleFilter = () => {
  showFilterModal.value = true;
};

const handleFilterApply = filters => {
  columnFilters.value = filters;
  showFilterModal.value = false;
};

const hasActiveFilters = computed(() => {
  if (!columnFilters.value) return false;

  return (
    columnFilters.value.priority.length > 0 ||
    columnFilters.value.value.min ||
    columnFilters.value.value.max ||
    columnFilters.value.agent_id ||
    columnFilters.value.date.start ||
    columnFilters.value.date.end
  );
});

// Fechar menu ao clicar fora
onMounted(() => {
  document.addEventListener('click', () => {
    showOptionsMenu.value = false;
  });
});

onUnmounted(() => {
  document.removeEventListener('click', () => {
    showOptionsMenu.value = false;
  });
});

// Atualizar o watch para sincronizar as opções
watch(
  () => columnSettings.value.showAll,
  newValue => {
    if (newValue) {
      columnSettings.value.showWon = true;
      columnSettings.value.showLost = true;
    }
    saveColumnSettings();
  }
);

// Atualizar o watch para a opção "todos"
watch(
  [() => columnSettings.value.showWon, () => columnSettings.value.showLost],
  ([showWon, showLost]) => {
    columnSettings.value.showAll = showWon && showLost;
  }
);

const handleEditStage = () => {
  editingStageForm.value = {
    name: props.title,
    color: props.color,
    description: props.description || '',
  };
  showEditStageModal.value = true;
  showOptionsMenu.value = false;
};

const handleSaveStage = async () => {
  try {
    const funnel = store.getters['funnel/getSelectedFunnel'];
    const updatedStages = { ...funnel.stages };

    updatedStages[props.id] = {
      ...updatedStages[props.id],
      name: editingStageForm.value.name,
      color: editingStageForm.value.color,
      description: editingStageForm.value.description,
    };

    await FunnelAPI.update(funnel.id, {
      ...funnel,
      stages: updatedStages,
    });

    showEditStageModal.value = false;

    // Força atualização do store
    await store.dispatch('funnel/fetch');

    // Emite evento para atualizar o kanban
    emit('itemsUpdated');

    // Notifica sucesso
    emitter.emit('newToastMessage', {
      message: 'Etapa atualizada com sucesso',
      action: { type: 'success' },
    });
  } catch (error) {
    console.error('Erro ao atualizar etapa:', error);
    emitter.emit('newToastMessage', {
      message: 'Erro ao atualizar etapa',
      action: { type: 'error' },
    });
  }
};

// Nova função para colapsar ou expandir todos os itens da coluna
const toggleAllItems = () => {
  // Atualiza o estado local
  allItemsCollapsed.value = !allItemsCollapsed.value;

  // Carrega as informações de colapso existentes
  const collapsedItems = JSON.parse(
    localStorage.getItem('kanban_collapsed_items') || '{}'
  );

  // Atualiza o estado de todos os itens da coluna
  filteredItems.value.forEach(item => {
    collapsedItems[item.id] = allItemsCollapsed.value;
  });

  // Salva de volta no localStorage
  localStorage.setItem(
    'kanban_collapsed_items',
    JSON.stringify(collapsedItems)
  );

  // Fecha o menu de opções
  showOptionsMenu.value = false;

  // Força a atualização dos componentes KanbanItem
  // Emite evento especial para forçar os itens a recarregarem seu estado
  emit('itemsUpdated');

  // Dispara um evento global para notificar os itens
  emitter.emit('kanbanItemsCollapsedStateChanged');
};

console.log(
  '[COLUMN-DEBUG] Coluna renderizada:',
  props.id,
  'com',
  props.items.length,
  'itens'
);
</script>

<template>
  <div
    v-show="!columnSettings.hideColumn"
    class="flex flex-col rounded-lg overflow-hidden"
    :style="{ ...columnWidth, ...columnStyle }"
  >
    <div
      class="pl-4 pr-4 pt-2 pb-2"
      :style="{ borderBottom: `1px solid ${props.color}59` }"
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <h3 class="text-sm font-medium" :style="{ color: textColor }">
            {{ title }}
          </h3>
          <span
            class="inline-flex items-center justify-center w-5 h-5 text-xs font-medium rounded-full"
            :style="countStyle"
          >
            {{ filteredItems.length }}
          </span>
          <!-- Indicador de filtro ativo -->
          <span
            v-if="hasActiveFilters"
            class="filter-active-indicator"
            :style="{ backgroundColor: textColor }"
          />
        </div>
        <div class="flex items-center gap-2">
          <span
            v-if="formattedTotal"
            class="text-xs font-medium"
            :style="{ color: textColor }"
          >
            {{ formattedTotal }}
          </span>
          <!-- Botão de filtro -->
          <button
            class="p-1 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100"
            @click="handleFilter"
          >
            <fluent-icon icon="filter" size="16" />
          </button>
          <button
            class="p-1 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100"
            @click="$emit('add', id)"
          >
            <fluent-icon icon="add" size="16" />
          </button>
          <!-- Botão de mais opções -->
          <div class="relative">
            <button
              class="p-1 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100"
              @click.stop="showOptionsMenu = !showOptionsMenu"
            >
              <fluent-icon icon="more-vertical" size="16" />
            </button>

            <!-- Menu de Opções -->
            <div
              v-if="showOptionsMenu"
              class="absolute right-0 top-full mt-1 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-2 w-48 z-10"
              @click.stop
            >
              <div class="px-4 py-2">
                <button
                  class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200 w-full hover:text-woot-500"
                  @click="handleEditStage"
                >
                  <fluent-icon icon="edit" size="16" />
                  <span>Editar Etapa</span>
                </button>
              </div>
              <div
                class="border-t border-slate-100 dark:border-slate-700 my-1"
              ></div>
              <div class="px-4 py-2">
                <label
                  class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200"
                >
                  <input
                    v-model="columnSettings.showAll"
                    type="checkbox"
                    class="form-checkbox"
                    @change="saveColumnSettings"
                  />
                  <span>Exibir Todos</span>
                </label>
              </div>
              <div class="px-4 py-2">
                <label
                  class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200"
                >
                  <input
                    v-model="columnSettings.showWon"
                    type="checkbox"
                    class="form-checkbox"
                    @change="saveColumnSettings"
                  />
                  <span>Exibir Ganhos</span>
                </label>
              </div>
              <div class="px-4 py-2">
                <label
                  class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200"
                >
                  <input
                    v-model="columnSettings.showLost"
                    type="checkbox"
                    class="form-checkbox"
                    @change="saveColumnSettings"
                  />
                  <span>Exibir Perdidos</span>
                </label>
              </div>
              <div class="px-4 py-2">
                <label
                  class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200"
                >
                  <input
                    v-model="columnSettings.hideColumn"
                    type="checkbox"
                    class="form-checkbox"
                    @change="saveColumnSettings"
                  />
                  <span>Ocultar Etapa</span>
                </label>
              </div>
              <div class="px-4 py-2">
                <button
                  class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200 w-full hover:text-woot-500"
                  @click="showSortModal = true"
                >
                  <fluent-icon icon="arrow-sort" size="16" />
                  <span>Ordenar</span>
                </button>
              </div>
              <div
                class="border-t border-slate-100 dark:border-slate-700 my-1"
              ></div>
              <div class="px-4 py-2">
                <button
                  class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200 w-full hover:text-woot-500"
                  @click="toggleAllItems"
                >
                  <fluent-icon
                    :icon="
                      allItemsCollapsed ? 'arrow-expand' : 'arrow-outwards'
                    "
                    size="16"
                  />
                  <span>{{
                    allItemsCollapsed ? 'Expandir todos' : 'Colapsar todos'
                  }}</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div
      class="flex-1 overflow-y-auto"
      @drop="handleDrop"
      @dragover="handleDragOver"
    >
      <div class="px-4">
        <div class="py-3 space-y-3">
          <template v-if="filteredItems.length">
            <KanbanItem
              v-for="item in filteredItems"
              :key="item.id"
              :item="item"
              :kanban-items="props.items"
              draggable
              @dragstart="
                e => {
                  e.dataTransfer.setData('text/plain', item.id.toString());
                }
              "
              @click="
                modifiedItem => {
                  console.log(
                    '[DEBUG] KanbanColumn - Item clicado:',
                    modifiedItem
                  );
                  console.log(
                    '[DEBUG] KanbanColumn - Description no clique:',
                    modifiedItem?.item_details?.description
                  );
                  $emit('itemClick', modifiedItem);
                }
              "
              @edit="
                modifiedItem => {
                  console.log(
                    '[DEBUG] KanbanColumn - Item editado:',
                    modifiedItem
                  );
                  console.log(
                    '[DEBUG] KanbanColumn - Description na edição:',
                    modifiedItem?.item_details?.description
                  );
                  $emit('edit', modifiedItem);
                }
              "
              @delete="$emit('delete', item)"
            />
          </template>
          <div
            v-else
            class="flex items-center justify-center h-24 text-sm text-slate-500 dark:text-slate-400"
          >
            {{
              hasActiveFilters ? t('NO_FILTERED_ITEMS') : t('KANBAN.NO_ITEMS')
            }}
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de filtro -->
    <KanbanFilter
      :show="showFilterModal"
      :filtered-results="filteredResults"
      @close="showFilterModal = false"
      @apply="handleFilterApply"
    />

    <!-- Modal de Edição de Etapa -->
    <Modal
      v-model:show="showEditStageModal"
      :on-close="() => (showEditStageModal = false)"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">Editar Etapa</h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium mb-1">Nome</label>
            <input
              v-model="editingStageForm.name"
              type="text"
              class="w-full px-3 py-2 border rounded-lg"
              placeholder="Nome da etapa"
            />
          </div>

          <div>
            <label class="block text-sm font-medium mb-1">Cor</label>
            <StageColorPicker v-model="editingStageForm.color" />
          </div>

          <div>
            <label class="block text-sm font-medium mb-1">Descrição</label>
            <textarea
              v-model="editingStageForm.description"
              class="w-full px-3 py-2 border rounded-lg"
              rows="3"
              placeholder="Descrição da etapa"
            />
          </div>

          <div class="flex justify-end gap-2">
            <woot-button variant="clear" @click="showEditStageModal = false">
              Cancelar
            </woot-button>
            <woot-button variant="primary" @click="handleSaveStage">
              Salvar
            </woot-button>
          </div>
        </div>
      </div>
    </Modal>

    <!-- Modal de Ordenação -->
    <Modal
      v-model:show="showSortModal"
      :on-close="() => (showSortModal = false)"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">Ordenar Itens</h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium mb-2">Ordenar por</label>
            <select
              v-model="columnSort.type"
              class="w-full px-3 py-2 border rounded-lg"
              @change="saveSortSettings"
            >
              <option
                v-for="option in sortOptions"
                :key="option.id"
                :value="option.id"
              >
                {{ option.label }}
              </option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium mb-2">Direção</label>
            <div class="flex gap-4">
              <label class="flex items-center gap-2">
                <input
                  type="radio"
                  v-model="columnSort.direction"
                  value="asc"
                  @change="saveSortSettings"
                />
                <span class="text-sm">Crescente</span>
              </label>
              <label class="flex items-center gap-2">
                <input
                  type="radio"
                  v-model="columnSort.direction"
                  value="desc"
                  @change="saveSortSettings"
                />
                <span class="text-sm">Decrescente</span>
              </label>
            </div>
          </div>

          <div class="flex justify-end gap-2">
            <woot-button variant="clear" @click="showSortModal = false">
              Cancelar
            </woot-button>
            <woot-button variant="primary" @click="showSortModal = false">
              Aplicar
            </woot-button>
          </div>
        </div>
      </div>
    </Modal>
  </div>
</template>

<style lang="scss" scoped>
.overflow-y-auto {
  min-height: 0;
  height: 100%;

  scrollbar-width: none;

  &::-webkit-scrollbar {
    display: none;
  }
}

.space-y-3 > :not([hidden]) ~ :not([hidden]) {
  margin-top: 0.75rem;
}

.space-y-3 > :last-child {
  margin-bottom: 0;
}

.filter-active-indicator {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  display: inline-block;
}

.form-checkbox {
  @apply rounded border-slate-300 text-woot-500 shadow-sm focus:border-woot-500 focus:ring focus:ring-woot-500 focus:ring-opacity-50;
}
</style>
