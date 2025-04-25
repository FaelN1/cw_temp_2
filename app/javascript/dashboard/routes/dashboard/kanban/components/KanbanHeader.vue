<script setup>
import { ref, computed, nextTick, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import Modal from '../../../../components/Modal.vue';
import KanbanItemForm from './KanbanItemForm.vue';
import FunnelSelector from './FunnelSelector.vue';
import KanbanSettings from './KanbanSettings.vue';
import BulkDeleteModal from './BulkDeleteModal.vue';
import BulkMoveModal from './BulkMoveModal.vue';
import BulkAddModal from './BulkAddModal.vue';
import KanbanAPI from '../../../../api/kanban';
import KanbanFilter from './KanbanFilter.vue';
import KanbanAI from './KanbanAI.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import FunnelAPI from '../../../../api/funnel';
import FunnelForm from './FunnelForm.vue';
import SendMessageTemplate from './SendMessageTemplate.vue';
import BulkSendMessageModal from './BulkSendMessageModal.vue';

// Função utilitária de debounce
const debounce = (fn, delay) => {
  let timeoutId;
  return (...args) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), delay);
  };
};

const { t } = useI18n();
const store = useStore();
const emit = defineEmits([
  'filter',
  'itemCreated',
  'search',
  'itemsUpdated',
  'switchView',
  'newToastMessage',
]);

const showAddModal = ref(false);
const selectedFunnel = computed(
  () => store.getters['funnel/getSelectedFunnel']
);

const props = defineProps({
  currentStage: {
    type: String,
    default: '',
  },
  searchResults: {
    type: Object,
    default: () => ({ total: 0, stages: {} }),
  },
  columns: {
    type: Array,
    default: () => [],
  },
  activeFilters: {
    type: Object,
    default: null,
  },
  currentView: {
    type: String,
    default: 'kanban',
  },
  kanbanItems: {
    type: Array,
    required: true,
  },
});

const showSettingsModal = ref(false);

const showSearchInput = ref(false);
const searchQuery = ref('');
const showResultsDetails = ref(false);

const showBulkActions = ref(false);

const showHiddenStages = ref(false);

const bulkActions = [
  {
    id: 'add',
    label: t('KANBAN.BULK_ACTIONS.ADD'),
    icon: 'add',
  },
  {
    id: 'move',
    label: t('KANBAN.BULK_ACTIONS.MOVE'),
    icon: 'arrow-right',
  },
  {
    id: 'delete',
    label: t('KANBAN.BULK_ACTIONS.DELETE.TITLE'),
    icon: 'delete',
  },
  {
    id: 'show_hidden',
    label: t('KANBAN.BULK_ACTIONS.SHOW_HIDDEN'),
    icon: 'eye-show',
  },
  {
    id: 'send_message',
    label: t('KANBAN.BULK_ACTIONS.SEND_MESSAGE.TITLE'),
    icon: 'chat',
  },
];

const showBulkDeleteModal = ref(false);
const showBulkMoveModal = ref(false);
const showBulkAddModal = ref(false);

const showSettingsDropdown = ref(false);

const userIsAdmin = computed(() => {
  const currentUser = store.getters.getCurrentUser;
  return currentUser?.role === 'administrator';
});

const settingsOptions = computed(() => {
  const options = [
    {
      id: 'kanban_settings',
      label: t('KANBAN.MORE_OPTIONS.KANBAN_SETTINGS'),
      icon: 'settings',
    },
    {
      id: 'message_templates',
      label: t('KANBAN.MORE_OPTIONS.MESSAGE_TEMPLATES'),
      icon: 'document',
    },
  ];

  if (userIsAdmin.value) {
    options.unshift({
      id: 'manage_funnels',
      label: t('KANBAN.MORE_OPTIONS.MANAGE_FUNNELS'),
      icon: 'task',
    });

    // options.unshift({
    //   id: 'automations',
    //   label: t('KANBAN.MORE_OPTIONS.AUTOMATIONS'),
    //   icon: 'star-emphasis',
    // });
  }

  return options;
});

const handleSettingsOption = option => {
  if (option.id === 'kanban_settings') {
    showSettingsModal.value = true;
  } else if (option.id === 'manage_funnels') {
    emit('switchView', 'funnels');
  } else if (option.id === 'automations') {
    emit('switchView', 'automation-editor');
  } else if (option.id === 'message_templates') {
    handleMessageTemplates();
  }
  showSettingsDropdown.value = false;
};

const handleSettingsClick = () => {
  showSettingsDropdown.value = !showSettingsDropdown.value;
};

const handleBulkActions = () => {
  showBulkActions.value = !showBulkActions.value;
};

const selectBulkAction = action => {
  if (action.id === 'show_hidden') {
    showHiddenStages.value = !showHiddenStages.value;

    // Verifica se existem colunas ocultas antes de alterar
    const hasHiddenColumns = props.columns.some(column => {
      const settings = JSON.parse(
        localStorage.getItem(`kanban_column_${column.id}_settings`) || '{}'
      );
      return settings.hideColumn === true;
    });

    // Só altera se existirem colunas ocultas ou se estiver desativando
    if (hasHiddenColumns || !showHiddenStages.value) {
      props.columns.forEach(column => {
        const settings = JSON.parse(
          localStorage.getItem(`kanban_column_${column.id}_settings`) || '{}'
        );

        // Só altera se a coluna estiver oculta
        if (settings.hideColumn === true) {
          settings.hideColumn = !showHiddenStages.value;
          localStorage.setItem(
            `kanban_column_${column.id}_settings`,
            JSON.stringify(settings)
          );
        }
      });

      emit('itemsUpdated');
    }
  } else if (action.id === 'delete') {
    showBulkDeleteModal.value = true;
  } else if (action.id === 'move') {
    showBulkMoveModal.value = true;
  } else if (action.id === 'add') {
    showBulkAddModal.value = true;
  } else if (action.id === 'send_message') {
    if (itemsWithConversation.value.length === 0) {
      emit('newToastMessage', {
        message: 'Nenhum item com conversa vinculada',
        action: { type: 'warning' },
      });
      return;
    }
    showSendMessageModal.value = true;
  }
  showBulkActions.value = false;
};

const showFilterModal = ref(false);

const handleFilterApply = filters => {
  emit('filter', filters);
  showFilterModal.value = false;
};

const handleFilter = () => {
  showFilterModal.value = true;
};

const handleSettings = () => {
  showSettingsModal.value = true;
};

const handleCloseSettings = () => {
  showSettingsModal.value = false;
};

const showAddDropdown = ref(false);
const showNewFunnelModal = ref(false);

const handleAdd = () => {
  showAddDropdown.value = !showAddDropdown.value;
};

const handleNewItem = () => {
  if (!selectedFunnel.value?.id) {
    emit('newToastMessage', {
      message: t('KANBAN.ERRORS.NO_FUNNEL_SELECTED'),
      action: { type: 'error' },
    });
    return;
  }
  showAddModal.value = true;
  showAddDropdown.value = false;
};

const handleNewFunnel = () => {
  showNewFunnelModal.value = true;
  showAddDropdown.value = false;
};

const handleFunnelSaved = funnel => {
  showNewFunnelModal.value = false;
  emit('itemsUpdated');
};

const handleItemCreated = async item => {
  emit('itemCreated', item);
  showAddModal.value = false;
};

const handleSearch = () => {
  showSearchInput.value = !showSearchInput.value;
  if (showSearchInput.value) {
    nextTick(() => {
      document.getElementById('kanban-search').focus();
    });
  } else {
    // Limpa a busca ao fechar
    searchQuery.value = '';
    emit('search', '');
  }
};

// Watch para manter o input visível enquanto houver busca
watch(searchQuery, newValue => {
  if (newValue) {
    showSearchInput.value = true;
  }
});

const onSearch = debounce(e => {
  const query = e.target.value;
  searchQuery.value = query;
  emit('search', query);
}, 300);

const handleBulkDelete = async selectedIds => {
  try {
    await Promise.all(selectedIds.map(id => KanbanAPI.deleteItem(id)));
    showBulkDeleteModal.value = false;
    emit('itemsUpdated');
  } catch (error) {
    console.error('Erro ao excluir itens:', error);
  }
};

const handleBulkMove = async ({ itemIds, stageId }) => {
  try {
    await Promise.all(itemIds.map(id => KanbanAPI.moveToStage(id, stageId)));
    showBulkMoveModal.value = false;
    emit('itemsUpdated');
  } catch (error) {
    console.error('Erro ao mover itens:', error);
  }
};

const handleBulkItemsCreated = async () => {
  showBulkAddModal.value = false;
  emit('itemsUpdated');
};

// Função para obter a cor da etapa
const getStageColor = stageName => {
  const column = props.columns.find(col => col.title === stageName);
  return column?.color ? `${column.color}` : '#64748B';
};

const handleMessageTemplates = () => {
  emit('switchView', 'templates');
};

// Computed para contar filtros ativos
const activeFiltersCount = computed(() => {
  if (!props.activeFilters) return 0;

  let count = 0;
  if (props.activeFilters.priority?.length) count++;
  if (props.activeFilters.value?.min || props.activeFilters.value?.max) count++;
  if (props.activeFilters.agent_id) count++;
  if (props.activeFilters.date?.start || props.activeFilters.date?.end) count++;

  return count;
});

const handleViewChange = view => {
  emit('switchView', view);
};

const showAIModal = ref(false);

// Usar getter do store para obter agentes
const filteredAgents = computed(() => {
  // Usar os agentes do funil atual
  const agentsFromFunnel = selectedFunnel.value?.settings?.agents || [];

  if (!searchQuery.value) return agentsFromFunnel;

  const query = searchQuery.value.toLowerCase();
  return agentsFromFunnel.filter(
    agent =>
      agent.name.toLowerCase().includes(query) ||
      agent.email.toLowerCase().includes(query)
  );
});

const handleAIClick = () => {
  showAIModal.value = true;
};

const toggleAgent = async agent => {
  try {
    const currentAgents = selectedFunnel.value.settings?.agents || [];
    const index = currentAgents.findIndex(a => a.id === agent.id);

    let updatedAgents;
    if (index === -1) {
      updatedAgents = [...currentAgents, agent];
    } else {
      updatedAgents = currentAgents.filter(a => a.id !== agent.id);
    }

    // Prepara o payload mantendo todos os dados existentes
    const payload = {
      ...selectedFunnel.value,
      settings: {
        ...selectedFunnel.value.settings,
        agents: updatedAgents,
        optimization_history:
          selectedFunnel.value.settings?.optimization_history || [],
      },
      stages: Object.entries(selectedFunnel.value.stages || {}).reduce(
        (acc, [id, stage]) => ({
          ...acc,
          [id]: {
            ...stage,
            message_templates: stage.message_templates || [], // Mantém os templates
          },
        }),
        {}
      ),
    };

    // Atualiza o funil
    await FunnelAPI.update(selectedFunnel.value.id, payload);
    await store.dispatch('funnel/fetch');
  } catch (error) {
    console.error('Erro ao atualizar agentes:', error);
  }
};

onMounted(() => {
  // Remover: store.dispatch('agents/get');
});

// Adicionar ref para controlar modal
const showSendMessageModal = ref(false);
// Adicionar ref para controlar modal de compartilhamento
const showShareModal = ref(false);

// Função para filtrar itens com conversa
const itemsWithConversation = computed(() => {
  return props.kanbanItems.filter(item => item.item_details?.conversation_id);
});

// Função para enviar mensagem em massa
const handleMessageSent = async () => {
  showSendMessageModal.value = false;
  emit('newToastMessage', {
    message: 'Mensagens enviadas com sucesso',
    action: { type: 'success' },
  });
};

// Adicionar ref para controlar modal de visualização
const showViewModal = ref(false);
</script>

<template>
  <header class="kanban-header">
    <div class="header-left">
      <button class="kanban-ai-button md:flex hidden" @click="handleAIClick">
        <svg
          class="lightning-icon"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M13 3L4 14H12L11 21L20 10H12L13 3Z" fill="currentColor" />
        </svg>
        <span class="lg:inline hidden">Kanban AI</span>
      </button>

      <!-- Botão para selecionar visualização no mobile -->
      <button
        class="view-select-btn md:hidden flex items-center gap-1 px-2 py-1.5 rounded-lg bg-slate-100 dark:bg-slate-700"
        @click="showViewModal = true"
      >
        <fluent-icon
          :icon="
            currentView === 'kanban'
              ? 'task'
              : currentView === 'list'
                ? 'list'
                : 'calendar'
          "
          size="16"
        />
        <fluent-icon icon="chevron-down" size="12" />
      </button>

      <!-- Esconder completamente em mobile -->
      <div class="view-toggle-buttons hidden md:flex">
        <woot-button
          variant="clear"
          size="small"
          :class="{ active: currentView === 'kanban' }"
          @click="emit('switchView', 'kanban')"
        >
          <fluent-icon icon="task" size="16" />
        </woot-button>
        <woot-button
          variant="clear"
          size="small"
          :class="{ active: currentView === 'list' }"
          @click="emit('switchView', 'list')"
        >
          <fluent-icon icon="list" size="16" />
        </woot-button>
        <woot-button
          variant="clear"
          size="small"
          :class="{ active: currentView === 'agenda' }"
          @click="emit('switchView', 'agenda')"
        >
          <fluent-icon icon="calendar" size="16" />
        </woot-button>
      </div>
      <funnel-selector class="md:block hidden" />
      <div
        class="search-container md:flex hidden"
        :class="{ 'is-active': showSearchInput }"
      >
        <woot-button variant="clear" size="small" @click="handleSearch">
          <fluent-icon icon="search" size="16" />
        </woot-button>
        <div v-show="showSearchInput" class="search-input-wrapper">
          <input
            id="kanban-search"
            v-model="searchQuery"
            type="search"
            class="search-input"
            :placeholder="t('KANBAN.SEARCH.INPUT_PLACEHOLDER')"
            @input="onSearch"
            @blur="!searchQuery && (showSearchInput = false)"
          />
          <div
            v-if="searchQuery && searchResults.total > 0"
            class="search-results-tags"
          >
            <div class="search-results-tag">
              {{ searchResults.total }} resultado(s)
            </div>
            <div
              v-for="(count, stageName) in searchResults.stages"
              :key="stageName"
              class="search-results-tag"
              :style="{ backgroundColor: getStageColor(stageName) }"
            >
              <span class="stage-name">{{ stageName }}</span>
              <span class="count-badge">{{ count }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="header-right">
      <div class="bulk-actions-selector md:block hidden">
        <woot-button variant="link" size="small" @click="handleBulkActions">
          <fluent-icon icon="list" size="16" class="mr-1" />
          <span class="lg:inline hidden">{{
            t('KANBAN.BULK_ACTIONS.TITLE')
          }}</span>
          <fluent-icon icon="chevron-down" size="16" class="ml-1" />
        </woot-button>

        <div v-if="showBulkActions" class="dropdown-menu">
          <div
            v-for="action in bulkActions"
            :key="action.id"
            class="dropdown-item"
            @click="selectBulkAction(action)"
          >
            <fluent-icon :icon="action.icon" size="16" class="mr-2" />
            <span>{{ action.label }}</span>
            <span
              v-if="action.id === 'show_hidden'"
              class="ml-2 text-xs px-1.5 rounded-full"
              :class="{
                'bg-woot-500 text-white': showHiddenStages,
                'bg-slate-100 text-slate-600': !showHiddenStages,
              }"
            >
              {{ showHiddenStages ? 'Ativo' : 'Inativo' }}
            </span>
          </div>
        </div>
      </div>

      <woot-button
        variant="clear"
        color-scheme="secondary"
        class="relative"
        @click="$emit('filter')"
      >
        <fluent-icon icon="filter" />
        <span v-if="activeFiltersCount > 0" class="filter-badge">
          {{ activeFiltersCount }}
        </span>
      </woot-button>
      <div class="share-button-container md:flex hidden">
        <div
          class="agents-stack"
          v-if="selectedFunnel?.settings?.agents?.length"
        >
          <Avatar
            v-for="(agent, index) in selectedFunnel.settings.agents.slice(0, 3)"
            :key="agent.id"
            :name="agent.name"
            :src="agent.avatar_url"
            :size="24"
            class="agent-avatar"
            :style="{ zIndex: 3 - index }"
          />
          <div
            v-if="selectedFunnel.settings.agents.length > 3"
            class="more-agents"
          >
            +{{ selectedFunnel.settings.agents.length - 3 }}
          </div>
        </div>
        <woot-button
          variant="clear"
          size="small"
          class="share-button"
          @click="showShareModal = true"
        >
          <div class="share-button-content">
            <fluent-icon icon="share" size="16" class="share-icon" />
            <span class="share-button-text lg:inline hidden">{{
              t('KANBAN.SHARE.TITLE')
            }}</span>
          </div>
        </woot-button>
      </div>
      <div class="relative md:block hidden">
        <woot-button
          variant="smooth"
          color-scheme="primary"
          size="small"
          class="add-item-btn"
          @click="handleAdd"
        >
          <fluent-icon icon="add" size="16" class="mr-1" />
        </woot-button>

        <div
          v-if="showAddDropdown"
          class="absolute right-0 top-full mt-1 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-2 w-48 z-10"
          @click.stop
        >
          <div
            class="px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 cursor-pointer"
            @click="handleNewItem"
          >
            <span class="flex items-center gap-2">
              <fluent-icon icon="add" size="16" />
              {{ t('KANBAN.ADD_ITEM') }}
            </span>
          </div>
          <div
            class="px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 cursor-pointer"
            @click="handleNewFunnel"
          >
            <span class="flex items-center gap-2">
              <fluent-icon icon="task" size="16" />
              {{ t('KANBAN.FUNNELS.ACTIONS.NEW') }}
            </span>
          </div>
        </div>
      </div>
      <div class="settings-selector">
        <woot-button
          variant="clear"
          size="small"
          @click="handleSettingsClick"
          :title="
            !userIsAdmin ? 'Apenas administradores podem gerenciar funis' : ''
          "
        >
          <fluent-icon icon="more-vertical" size="16" />
        </woot-button>

        <div
          v-if="showSettingsDropdown"
          class="dropdown-menu"
          @mouseleave="showSettingsDropdown = false"
        >
          <div
            v-for="option in settingsOptions"
            :key="option.id"
            class="dropdown-item"
            @click="handleSettingsOption(option)"
          >
            <fluent-icon :icon="option.icon" size="16" class="mr-2" />
            {{ option.label }}
          </div>
        </div>
      </div>
    </div>

    <!-- Menu móvel para elementos ocultos -->
    <!-- Navbar inferior removida conforme solicitado -->

    <!-- Modal para seleção de visualização -->
    <Modal
      v-model:show="showViewModal"
      :on-close="() => (showViewModal = false)"
      size="tiny"
    >
      <div class="p-4">
        <h3 class="text-lg font-medium mb-4">Selecionar visualização</h3>
        <div class="flex flex-col gap-3">
          <button
            class="flex items-center gap-3 p-3 rounded-lg text-left"
            :class="{
              'bg-woot-50 text-woot-600 dark:bg-woot-900/20 dark:text-woot-300':
                currentView === 'kanban',
              'hover:bg-slate-50 dark:hover:bg-slate-700':
                currentView !== 'kanban',
            }"
            @click="
              emit('switchView', 'kanban');
              showViewModal = false;
            "
          >
            <fluent-icon icon="task" size="20" />
            <div>
              <div class="font-medium">Kanban</div>
              <div class="text-xs text-slate-500 dark:text-slate-400">
                Visualização em quadro
              </div>
            </div>
          </button>

          <button
            class="flex items-center gap-3 p-3 rounded-lg text-left"
            :class="{
              'bg-woot-50 text-woot-600 dark:bg-woot-900/20 dark:text-woot-300':
                currentView === 'list',
              'hover:bg-slate-50 dark:hover:bg-slate-700':
                currentView !== 'list',
            }"
            @click="
              emit('switchView', 'list');
              showViewModal = false;
            "
          >
            <fluent-icon icon="list" size="20" />
            <div>
              <div class="font-medium">Lista</div>
              <div class="text-xs text-slate-500 dark:text-slate-400">
                {{ t('VIEW_MODES.LIST') }}
              </div>
            </div>
          </button>

          <button
            class="flex items-center gap-3 p-3 rounded-lg text-left"
            :class="{
              'bg-woot-50 text-woot-600 dark:bg-woot-900/20 dark:text-woot-300':
                currentView === 'agenda',
              'hover:bg-slate-50 dark:hover:bg-slate-700':
                currentView !== 'agenda',
            }"
            @click="
              emit('switchView', 'agenda');
              showViewModal = false;
            "
          >
            <fluent-icon icon="calendar" size="20" />
            <div>
              <div class="font-medium">Agenda</div>
              <div class="text-xs text-slate-500 dark:text-slate-400">
                {{ t('KANBAN.VIEW_MODES.AGENDA') }}
              </div>
            </div>
          </button>
        </div>
      </div>
    </Modal>

    <Modal
      v-model:show="showAddModal"
      :on-close="() => (showAddModal = false)"
      size="large"
    >
      <div class="w-full p-6">
        <h3 class="text-lg font-medium mb-6">
          {{ t('KANBAN.ADD_ITEM') }}
        </h3>
        <KanbanItemForm
          v-if="selectedFunnel"
          :funnel-id="selectedFunnel.id"
          :stage="currentStage"
          @saved="handleItemCreated"
          @close="showAddModal = false"
        />
        <div v-else class="text-center text-red-500">
          {{ t('KANBAN.ERRORS.NO_FUNNEL_SELECTED') }}
        </div>
      </div>
    </Modal>

    <KanbanSettings :show="showSettingsModal" @close="handleCloseSettings" />

    <Modal
      v-model:show="showBulkDeleteModal"
      :on-close="() => (showBulkDeleteModal = false)"
    >
      <BulkDeleteModal
        :items="kanbanItems"
        @close="showBulkDeleteModal = false"
        @confirm="handleBulkDelete"
      />
    </Modal>

    <Modal
      v-model:show="showBulkMoveModal"
      :on-close="() => (showBulkMoveModal = false)"
    >
      <BulkMoveModal
        :items="kanbanItems"
        @close="showBulkMoveModal = false"
        @confirm="handleBulkMove"
      />
    </Modal>

    <Modal
      v-model:show="showBulkAddModal"
      :on-close="() => (showBulkAddModal = false)"
    >
      <BulkAddModal
        :current-stage="currentStage"
        @close="showBulkAddModal = false"
        @items-created="handleBulkItemsCreated"
      />
    </Modal>

    <KanbanFilter
      :show="showFilterModal"
      @close="showFilterModal = false"
      @apply="handleFilterApply"
    />

    <!-- AI Modal -->
    <Modal
      v-model:show="showAIModal"
      :on-close="() => (showAIModal = false)"
      size="large"
      class="ai-modal"
      hide-close-button
    >
      <KanbanAI @close="showAIModal = false" />
    </Modal>

    <!-- Modal de compartilhamento -->
    <Modal
      v-model:show="showShareModal"
      :on-close="() => (showShareModal = false)"
      size="tiny"
    >
      <div class="p-4 space-y-4">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-medium">
            {{ t('KANBAN.SHARE.TITLE') }}
          </h3>
        </div>

        <div class="relative">
          <input
            v-model="searchQuery"
            type="text"
            class="w-full px-3 py-2 border rounded-lg pr-8"
            placeholder="Buscar agentes..."
          />
          <fluent-icon
            icon="search"
            size="16"
            class="absolute right-3 top-1/2 transform -translate-y-1/2 text-slate-400"
          />
        </div>

        <div class="max-h-[300px] overflow-y-auto space-y-2">
          <div
            v-for="agent in filteredAgents"
            :key="agent.id"
            class="flex items-center gap-3 p-2 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg cursor-pointer"
            :class="{
              'bg-woot-50 dark:bg-woot-900/20':
                selectedFunnel.settings?.agents?.some(a => a.id === agent.id),
            }"
            @click="toggleAgent(agent)"
          >
            <Avatar
              :name="agent.name"
              :src="agent.avatar_url"
              :size="32"
              :status="agent.availability_status"
            />
            <div class="flex-1 min-w-0">
              <div class="font-medium text-sm truncate">
                {{ agent.name }}
              </div>
              <div class="text-xs text-slate-500 dark:text-slate-400 truncate">
                {{ agent.email }}
              </div>
            </div>
            <fluent-icon
              v-if="
                selectedFunnel.settings?.agents?.some(a => a.id === agent.id)
              "
              icon="checkmark"
              size="16"
              class="text-woot-500"
            />
          </div>
        </div>
      </div>
    </Modal>

    <!-- Modal de Novo Funil -->
    <Modal
      v-model:show="showNewFunnelModal"
      :on-close="() => (showNewFunnelModal = false)"
      size="large"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.FUNNELS.ACTIONS.NEW') }}
        </h3>
        <FunnelForm
          @saved="handleFunnelSaved"
          @close="showNewFunnelModal = false"
        />
      </div>
    </Modal>

    <!-- Modal de Envio de Mensagem -->
    <Modal
      v-model:show="showSendMessageModal"
      :on-close="() => (showSendMessageModal = false)"
      size="medium"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">Enviar Mensagens em Massa</h3>
        <BulkSendMessageModal
          :items="itemsWithConversation"
          @close="showSendMessageModal = false"
          @send="handleMessageSent"
        />
      </div>
    </Modal>
  </header>
</template>

<style lang="scss" scoped>
.kanban-header {
  position: relative;
  z-index: 50;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--space-normal);
  border-bottom: 1px solid var(--color-border);

  @apply dark:border-slate-800 flex-wrap;

  @media (max-width: 768px) {
    padding: var(--space-small);
    gap: var(--space-small);
  }
}

.header-left {
  display: flex;
  align-items: center;
  gap: var(--space-normal);

  @media (max-width: 768px) {
    gap: var(--space-small);
    flex-wrap: wrap;
  }
}

.header-right {
  display: flex;
  align-items: center;
  gap: var(--space-small);

  @media (max-width: 768px) {
    gap: 4px;
  }
}

.search-container {
  @apply flex items-center relative;

  &.is-active {
    @apply bg-slate-50 dark:bg-slate-800 rounded-lg;

    .search-input-wrapper {
      width: auto;
      min-width: 300px;
      @apply flex items-center gap-2;
    }
  }
}

.search-input-wrapper {
  @apply overflow-hidden transition-all duration-200;
  width: 0;
}

.search-input {
  @apply h-8 px-2 m-0 text-sm text-slate-800 dark:text-slate-100;

  &:focus {
    @apply outline-none ring-0;
  }

  &::placeholder {
    @apply text-slate-500;
  }
}

.bulk-actions-selector {
  position: relative;
  display: inline-block;
}

.dropdown-menu {
  position: absolute;
  top: 100%;
  left: 0;
  z-index: 99999;
  min-width: 200px;
  margin-top: var(--space-micro);
  padding: var(--space-micro);
  background: var(--white);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-normal);
  box-shadow: var(--shadow-dropdown);

  @apply dark:bg-slate-800 dark:border-slate-700;
}

.dropdown-item {
  display: flex;
  align-items: center;
  padding: var(--space-small) var(--space-normal);
  cursor: pointer;
  border-radius: var(--border-radius-small);

  @apply dark:text-slate-100;

  &:hover {
    background: var(--color-background);
    @apply dark:bg-slate-700;
  }
}

.settings-selector {
  position: relative;
  display: inline-block;

  .dropdown-menu {
    right: 0;
    left: auto;
    transform: translateY(4px);
    z-index: 99999;
  }
}

.search-results-tags {
  @apply flex items-center gap-1 flex-wrap;
}

.search-results-tag {
  @apply flex items-center px-2 py-0.5 text-xs font-medium rounded-full
    bg-woot-500 text-white whitespace-nowrap gap-1;

  &:first-child {
    @apply bg-slate-600;
  }

  .stage-name {
    @apply text-[10px];
  }

  .count-badge {
    @apply bg-white/20 px-1.5 rounded-full text-[10px] min-w-[18px] text-center;
  }
}

.message-templates-btn {
  @apply border border-dashed border-woot-500 text-woot-500 hover:bg-woot-50
    dark:hover:bg-woot-800/20 transition-colors;

  &:hover {
    @apply border-woot-600 text-woot-600;
  }
}

.add-item-btn {
  @apply bg-woot-500 text-white p-2;

  .mr-1 {
    @apply m-0;
  }
}

.filter-badge {
  @apply absolute -top-1 -right-1 min-w-[16px] h-4 px-1
    flex items-center justify-center
    text-[10px] font-medium
    bg-woot-500 text-white
    rounded-full;
}

// Adicione estilos específicos para selects
select {
  @apply bg-white dark:bg-slate-800 cursor-pointer;
  @apply border border-slate-200 dark:border-slate-700;
  @apply rounded-lg px-3 py-2;
  @apply text-slate-800 dark:text-slate-100;
  @apply hover:border-slate-300 dark:hover:border-slate-600;
  @apply focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500;
  @apply disabled:opacity-50 disabled:cursor-not-allowed;
}

.view-toggle-buttons {
  @apply border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden;

  .woot-button {
    @apply px-2 py-1.5 border-0 rounded-none;

    &:first-child {
      @apply border-r border-slate-200 dark:border-slate-700;
    }

    &.active {
      @apply bg-slate-100 dark:bg-slate-700 text-woot-500;
    }

    &:hover:not(.active) {
      @apply bg-slate-50 dark:bg-slate-800;
    }
  }
}

.kanban-ai-button {
  @apply flex items-center gap-2 px-3 py-1.5 rounded-lg font-medium text-white text-sm;
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
  transition: all 0.2s ease;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);

  &:active {
    transform: translateY(0);
  }

  .lightning-icon {
    filter: drop-shadow(0 1px 1px rgba(0, 0, 0, 0.1));
  }
}

.ai-modal {
  :deep(.modal__content) {
    @apply w-[85vw] h-[85vh] max-w-[1400px] p-0;
  }
}

.share-button {
  @apply flex items-center px-3 py-1.5 rounded-lg font-medium text-white text-sm;
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
  transition: all 0.2s ease;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);

  .share-button-content {
    @apply flex items-center gap-2;
  }

  &:hover {
    filter: brightness(1.1);
  }

  &:active {
    transform: translateY(0);
  }

  .share-icon {
    @apply text-white;
  }

  .share-button-text {
    @apply text-white;
  }
}

.share-button-container {
  @apply flex items-center gap-2;
}

.agents-stack {
  @apply flex items-center;

  .agent-avatar {
    @apply border-2 border-white dark:border-slate-800;
    margin-left: -8px;

    &:first-child {
      margin-left: 0;
    }
  }

  .more-agents {
    @apply flex items-center justify-center
    w-6 h-6 rounded-full
    bg-slate-100 dark:bg-slate-700
    text-xs font-medium
    border-2 border-white dark:border-slate-800
    ml-[-8px];
  }
}

.view-select-btn {
  @apply text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-600;

  &:hover {
    @apply bg-slate-200 dark:bg-slate-600;
  }

  &:active {
    @apply bg-slate-300 dark:bg-slate-500;
  }
}
</style>
