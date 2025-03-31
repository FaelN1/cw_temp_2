<script setup>
import { ref, computed, onMounted, onUnmounted, markRaw, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { VueFlow, Panel, useVueFlow, Position } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { MiniMap } from '@vue-flow/minimap';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';
import '@vue-flow/minimap/dist/style.css';
import KanbanAPI from '../../../../api/kanban';
import { emitter } from 'shared/helpers/mitt';
import { useRouter } from 'vue-router';
import FlowBuilder from '../automations/FlowBuilder.vue';

// Componentes de nós personalizados
import TriggerNode from './flowNodes/TriggerNode.vue';
import ConditionNode from './flowNodes/ConditionNode.vue';
import ActionNode from './flowNodes/ActionNode.vue';

const props = defineProps({
  currentView: {
    type: String,
    default: 'kanban-view',
  },
  kanbanItems: {
    type: Array,
    default: () => [],
  },
  labelsMap: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['switchView']);
const { t } = useI18n();
const store = useStore();
const router = useRouter();

// Estado local
const name = ref('Nova Automação');
const description = ref('');
const active = ref(true);
const saving = ref(false);
const showActionToolbar = ref(false);
const actionToolbarPosition = ref({ x: 0, y: 0 });
const selectedNodeId = ref(null);
const elements = ref([]);
const selectedNode = ref(null);
const selectedAutomationId = ref(null);
const isCreatingNew = ref(false);
const automations = ref([]);
const isLoading = ref(true);

// Estado local para nodes e edges
const nodes = ref([
  {
    id: 'trigger',
    type: 'triggerNode',
    position: { x: 250, y: 5 },
    data: {
      label: 'When chat message received',
      type: 'message_received',
    },
    sourcePosition: 'bottom',
  },
  {
    id: 'agent',
    type: 'actionNode',
    position: { x: 250, y: 100 },
    data: {
      label: 'AI Agent',
      type: 'ai_agent',
      description: 'Tool Agent',
    },
    targetPosition: 'top',
    sourcePosition: 'bottom',
  },
  {
    id: 'condition',
    type: 'conditionNode',
    position: { x: 250, y: 200 },
    data: {
      label: 'If',
      field: 'success',
      operator: 'equals',
      value: true,
    },
    targetPosition: 'top',
    sourcePosition: 'bottom',
  },
  {
    id: 'success',
    type: 'actionNode',
    position: { x: 150, y: 300 },
    data: {
      label: 'Success',
      type: 'success',
      description: 'Send message',
    },
    targetPosition: 'top',
    className: 'success-node',
  },
  {
    id: 'failure',
    type: 'actionNode',
    position: { x: 350, y: 300 },
    data: {
      label: 'Failure',
      type: 'failure',
      description: 'Send message',
    },
    targetPosition: 'top',
    className: 'failure-node',
  },
]);

const edges = ref([
  {
    id: 'e-trigger-agent',
    source: 'trigger',
    target: 'agent',
  },
  {
    id: 'e-agent-condition',
    source: 'agent',
    target: 'condition',
  },
  {
    id: 'e-condition-success',
    source: 'condition',
    target: 'success',
    data: { label: 'true' },
    animated: true,
    type: 'straight',
    label: 'true',
    labelBgStyle: { fill: '#FFCC00' },
  },
  {
    id: 'e-condition-failure',
    source: 'condition',
    target: 'failure',
    data: { label: 'false' },
    animated: true,
    type: 'straight',
    label: 'false',
    labelBgStyle: { fill: '#FFCC00' },
  },
]);

// Obter dados do store
const isEditing = computed(() => store.getters['automationEditor/isEditing']);
const currentAutomation = computed(
  () => store.getters['automationEditor/getCurrentAutomation']
);
const flowNodes = computed(
  () => store.getters['automationEditor/getFlowNodes']
);
const flowEdges = computed(
  () => store.getters['automationEditor/getFlowEdges']
);

// Sync com o store
watch(
  () => store.getters['automationEditor/getFlowNodes'],
  newNodes => {
    nodes.value = newNodes;
  },
  { deep: true }
);

watch(
  () => store.getters['automationEditor/getFlowEdges'],
  newEdges => {
    edges.value = newEdges;
  },
  { deep: true }
);

// Configuração do Vue Flow
const nodeTypes = {
  triggerNode: markRaw(TriggerNode),
  conditionNode: markRaw(ConditionNode),
  actionNode: markRaw(ActionNode),
};

// Configurar as opções após a inicialização
onMounted(async () => {
  // Simplesmente carregar as automações
  isLoading.value = true;

  try {
    await store.dispatch('automationFlow/fetchAutomations');
    // Garantir que automations sempre seja um array
    automations.value = store.getters['automationFlow/getAutomations'] || [];
  } catch (error) {
    console.error('Erro ao carregar automações:', error);
    automations.value = []; // Garantir que sempre seja um array
  } finally {
    isLoading.value = false;
  }

  if (currentAutomation.value) {
    name.value = currentAutomation.value.name || '';
    description.value = currentAutomation.value.description || '';
    active.value =
      currentAutomation.value.active !== undefined
        ? currentAutomation.value.active
        : true;
  }
});

// Handler para atualização de nodes
const handleNodesChange = changes => {
  store.dispatch('automationEditor/updateFlowNodes', changes);
};

// Handler para atualização de edges
const handleEdgesChange = changes => {
  store.dispatch('automationEditor/updateFlowEdges', changes);
};

// Manipuladores de eventos
const handleConnect = params => {
  const newEdge = {
    id: `e-${params.source}-${params.target}`,
    source: params.source,
    target: params.target,
    animated: true,
  };

  edges.value.push(newEdge);
};

const handlePaneReady = () => {
  setTimeout(() => {
    if (vueFlowInstance && vueFlowInstance.fitView) {
      vueFlowInstance.fitView({ padding: 0.2 });
    }
  }, 100);
};

// Limpar o editor ao sair
onUnmounted(() => {
  store.dispatch('automationEditor/resetEditor');
});

// Correção para o manipulador de arrastar e soltar nós
const handleNodeDragStop = (event, node) => {
  if (!node?.id || !node?.position) return;

  // Desativando o log de console que pode causar problemas
  // console.log('Node Dragged:', { id: node.id, position: node.position });

  // Atualizar o nó no store sem modificar diretamente o array nodes
  store.commit('automationEditor/UPDATE_NODE_POSITION', {
    nodeId: node.id,
    position: node.position,
  });

  // Atualizar os internals do nó para garantir que as conexões permaneçam corretas
  vueFlowInstance.updateNodeInternals([node.id]);
};

// Atualizar o manipulador de clique para não interferir na posição
const handleNodeClick = (event, node) => {
  if (!node?.id) return;

  // Prevenir propagação do evento para evitar problemas de posicionamento
  event.stopPropagation();

  // Atualiza o nó selecionado
  selectedNode.value = node;
  selectedNodeId.value = node.id;
  showActionToolbar.value = true;

  const rect = event?.target?.getBoundingClientRect?.() || { right: 0, top: 0 };
  actionToolbarPosition.value = {
    x: rect.right + 10,
    y: rect.top,
  };
};

// Remover onPaneClick do useVueFlow e criar um handler direto
const handlePaneClick = () => {
  showActionToolbar.value = false;
  selectedNodeId.value = null;
  selectedNode.value = null;
};

// Função auxiliar para calcular posição do novo nó
const calculateNewNodePosition = () => {
  if (!nodes.value.length) {
    return { x: 250, y: 100 }; // Posição inicial do primeiro nó
  }

  // Encontra o último nó
  const lastNode = nodes.value[nodes.value.length - 1];

  // Retorna posição relativa ao último nó sem usar project()
  return {
    x: lastNode.position.x,
    y: lastNode.position.y + 150,
  };
};

// Ações da toolbar
const addConditionNode = () => {
  const nodeId = `condition-${Date.now()}`;
  const position = calculateNewNodePosition();

  store.dispatch('automationEditor/addNode', {
    id: nodeId,
    type: 'condition',
    position,
    sourcePosition: Position.Bottom,
    targetPosition: Position.Top,
    data: {
      field: '',
      operator: '',
      value: '',
    },
  });
};

const addActionNode = actionType => {
  const nodeId = `action-${Date.now()}`;
  const position = calculateNewNodePosition();
  let data = { type: actionType };

  // Configurar dados específicos para cada tipo de ação
  switch (actionType) {
    case 'move_to_column':
      data.column = '';
      break;
    case 'change_priority':
      data.priority = 'medium';
      break;
    case 'assign_agent':
      data.agent_id = '';
      break;
    case 'send_notification':
      data.message = '';
      break;
    case 'send_message':
      data.message = '';
      data.conversation_id = '';
      break;
    case 'update_contact':
      data.contact_id = '';
      data.attributes = {};
      break;
    case 'add_label':
      data.label = '';
      break;
    default:
      // Não fazer nada para tipos desconhecidos
      break;
  }

  store.dispatch('automationEditor/addNode', {
    id: nodeId,
    type: 'action',
    position,
    sourcePosition: Position.Bottom,
    targetPosition: Position.Top,
    data,
  });
};

const removeSelectedNode = () => {
  if (selectedNodeId.value && selectedNodeId.value !== 'trigger') {
    store.dispatch('automationEditor/removeNode', selectedNodeId.value);
    showActionToolbar.value = false;
    selectedNodeId.value = null;
  }
};

// Salvar automação
const saveAutomation = async () => {
  saving.value = true;

  try {
    // Construir objeto de automação
    const nodes = this.nodes;
    const edges = this.edges;

    // Encontrar nó trigger
    const triggerNode = nodes.find(node => node.type === 'triggerNode');
    if (!triggerNode) {
      throw new Error(t('KANBAN.AUTOMATIONS.ERRORS.NO_TRIGGER'));
    }

    // Encontrar nós de ação seguindo as conexões
    const actionNodes = nodes.filter(node => node.type === 'action');
    if (!actionNodes.length) {
      throw new Error(t('KANBAN.AUTOMATIONS.ERRORS.NO_ACTIONS'));
    }

    // Construir objeto de automação
    const automation = {
      name: name.value,
      description: description.value,
      active: active.value,
      trigger: {
        type: triggerNode.data.type,
        column: triggerNode.data.column,
        inactivity_period: triggerNode.data.inactivity_period,
      },
      conditions: nodes
        .filter(node => node.type === 'condition')
        .map(node => ({
          field: node.data.field,
          operator: node.data.operator,
          value: node.data.value,
        })),
      actions: actionNodes.map(node => ({
        type: node.data.type,
        ...node.data, // Inclui todos os dados específicos da ação
      })),
    };

    if (isEditing.value) {
      await KanbanAPI.updateAutomation(currentAutomation.value.id, automation);
      emitter.emit('newToastMessage', {
        message: t('KANBAN.AUTOMATIONS.UPDATE_SUCCESS'),
        type: 'success',
      });
    } else {
      await KanbanAPI.createAutomation(automation);
      emitter.emit('newToastMessage', {
        message: t('KANBAN.AUTOMATIONS.CREATE_SUCCESS'),
        type: 'success',
      });
    }

    emit('switchView', 'automations');
  } catch (error) {
    emitter.emit('newToastMessage', {
      message: error.message || t('KANBAN.AUTOMATIONS.ERRORS.SAVE_FAILED'),
      type: 'error',
    });
  } finally {
    saving.value = false;
  }
};

// Cancelar edição
const cancelEdit = () => {
  emit('switchView', 'automations');
};

// Atualiza elements quando flowNodes ou flowEdges mudam
watch([nodes, edges], ([newNodes, newEdges]) => {
  elements.value = [...newNodes, ...newEdges];
});

// Criar nova automação
const createNewAutomation = () => {
  try {
    // Limpar o estado atual
    selectedNodeId.value = null;
    elements.value = [];
    name.value = 'Nova Automação';
    description.value = '';
    active.value = true;

    // Inicializar com um nó de gatilho padrão
    store.dispatch('automationEditor/clearCurrentAutomation');

    // Inicializar com um nó de gatilho padrão
    const triggerNode = {
      id: 'trigger-1',
      type: 'triggerNode',
      position: { x: 250, y: 50 },
      data: {
        label: 'Quando item criado',
        type: 'item_created',
        column: 'all',
      },
    };

    store.dispatch('automationEditor/setFlowNodes', [triggerNode]);
    isCreatingNew.value = true;
  } catch (error) {
    console.error('Erro ao criar nova automação:', error);
    // Você pode adicionar tratamento de erro específico aqui
  }
};

// Editar automação existente
const editAutomation = id => {
  selectedAutomationId.value = id;
  isCreatingNew.value = false;
};

// Voltar para a lista de automações
const backToAutomationList = () => {
  selectedAutomationId.value = null;
  isCreatingNew.value = false;
};

// Voltar para o kanban
const backToKanban = () => {
  emit('switchView', 'kanban-view');
};

// Lidar com o salvamento da automação
const handleSave = () => {
  backToAutomationList();
};
</script>

<template>
  <div class="automation-editor-container">
    <!-- Exibir FlowBuilder quando estiver criando ou editando -->
    <div
      v-if="isCreatingNew || selectedAutomationId"
      class="flow-builder-wrapper"
    >
      <FlowBuilder
        :automation-id="selectedAutomationId"
        @close="backToAutomationList"
        @save="handleSave"
      />
    </div>

    <!-- Lista de automações quando não estiver criando/editando -->
    <div v-else class="automations-list">
      <div class="automations-header">
        <div class="header-left">
          <button class="back-button" @click="backToKanban">
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
        <div class="header-actions">
          <button class="primary-button" @click="createNewAutomation">
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
              <path d="M12 5v14M5 12h14"></path>
            </svg>
            {{ t('KANBAN.AUTOMATIONS.NEW') }}
          </button>
        </div>
      </div>

      <div class="automations-content">
        <!-- Estado de carregamento -->
        <div v-if="isLoading" class="loading-state">
          <div class="spinner"></div>
          <p>{{ t('KANBAN.AUTOMATIONS.LOADING') }}</p>
        </div>

        <!-- Lista vazia -->
        <div
          v-else-if="automations && automations.length === 0"
          class="empty-state"
        >
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
              <rect x="3" y="11" width="18" height="10" rx="2"></rect>
              <circle cx="12" cy="5" r="2"></circle>
              <path d="M12 7v4"></path>
              <line x1="8" y1="16" x2="8" y2="16"></line>
              <line x1="16" y1="16" x2="16" y2="16"></line>
            </svg>
          </div>
          <h3>{{ t('KANBAN.AUTOMATIONS.EMPTY_TITLE') }}</h3>
          <p>{{ t('KANBAN.AUTOMATIONS.CREATE_FIRST') }}</p>
          <button class="primary-button" @click="createNewAutomation">
            {{ t('KANBAN.AUTOMATIONS.CREATE_FIRST') }}
          </button>
        </div>

        <!-- Lista de automações -->
        <div v-else class="automations-list-items">
          <div
            v-for="automation in automations"
            :key="automation.id"
            class="automation-card"
            @click="editAutomation(automation.id)"
          >
            <div class="automation-icon">
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
                <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"></path>
              </svg>
            </div>
            <div class="automation-details">
              <h3 class="automation-name">{{ automation.name }}</h3>
              <p class="automation-description">
                {{ automation.description || '-' }}
              </p>
            </div>
            <div
              class="automation-status"
              :class="{ active: automation.active }"
            >
              {{
                automation.active
                  ? t('KANBAN.AUTOMATIONS.ACTIVE')
                  : t('KANBAN.AUTOMATIONS.INACTIVE')
              }}
            </div>
            <div class="automation-actions">
              <button class="icon-button">
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
                  <path d="M12 20h9"></path>
                  <path
                    d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"
                  ></path>
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.automation-editor-container {
  @apply flex flex-col h-full w-full bg-white dark:bg-slate-900;
}

.flow-builder-wrapper {
  @apply h-full w-full;
}

.automations-list {
  @apply flex flex-col h-full w-full;
}

.automations-header {
  @apply flex justify-between items-center p-4 border-b border-slate-200 dark:border-slate-700;
  height: 64px;

  .header-left {
    @apply flex items-center gap-4;
  }

  .back-button {
    @apply p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 
      text-slate-700 dark:text-slate-300 transition-colors;
  }

  .title {
    @apply text-xl font-medium text-slate-800 dark:text-slate-100;
  }

  .primary-button {
    @apply flex items-center gap-2 px-4 py-2 rounded-md
      bg-woot-500 text-white font-medium text-sm
      hover:bg-woot-600 transition-colors;
  }
}

.automations-content {
  @apply flex-1 p-4 overflow-auto;
}

.loading-state {
  @apply flex flex-col items-center justify-center h-full;

  .spinner {
    @apply w-10 h-10 border-4 border-slate-300 dark:border-slate-700 rounded-full mb-4;
    border-top-color: #3b82f6;
    animation: spin 1s linear infinite;
  }

  p {
    @apply text-slate-500 dark:text-slate-400;
  }
}

.empty-state {
  @apply flex flex-col items-center justify-center h-full text-center max-w-md mx-auto;

  .empty-icon {
    @apply w-16 h-16 flex items-center justify-center rounded-full
      bg-slate-100 dark:bg-slate-800 mb-4;

    i {
      @apply text-3xl text-slate-500 dark:text-slate-400;
    }
  }

  h3 {
    @apply text-xl font-medium text-slate-800 dark:text-slate-100 mb-2;
  }

  p {
    @apply text-slate-500 dark:text-slate-400 mb-6;
  }
}

.automations-list-items {
  @apply grid gap-4;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));

  .automation-card {
    @apply flex items-center p-4 rounded-lg bg-white dark:bg-slate-800
      border border-slate-200 dark:border-slate-700
      hover:shadow-md transition-shadow cursor-pointer;

    .automation-icon {
      @apply flex items-center justify-center w-10 h-10 rounded-md
        bg-slate-100 dark:bg-slate-700 mr-4;

      i {
        @apply text-slate-600 dark:text-slate-300;
      }
    }

    .automation-details {
      @apply flex-1 min-w-0;

      .automation-name {
        @apply text-base font-medium text-slate-800 dark:text-slate-100
          truncate;
      }

      .automation-description {
        @apply text-sm text-slate-500 dark:text-slate-400 truncate;
      }
    }

    .automation-status {
      @apply px-2 py-1 rounded-full text-xs font-medium
        bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 mr-2;

      &.active {
        @apply bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400;
      }
    }

    .automation-actions {
      .icon-button {
        @apply p-1 rounded-full text-slate-400 
          hover:bg-slate-100 dark:hover:bg-slate-700 
          hover:text-slate-600 dark:hover:text-slate-300;
      }
    }
  }
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
