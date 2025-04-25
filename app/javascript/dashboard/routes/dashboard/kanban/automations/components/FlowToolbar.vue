<script setup>
import { useStore } from 'vuex';
import { ref, computed } from 'vue';
import { addNode } from '../utils/flowHelpers';

const store = useStore();

// Estado para a categoria selecionada
const selectedCategory = ref(null);

// Categorias de elementos
const categories = [
  {
    id: 'trigger',
    icon: 'bolt',
    label: 'Disparadores',
    items: [
      { id: 'message_received', label: 'Mensagem recebida' },
      { id: 'item_created', label: 'Item criado' },
      { id: 'status_changed', label: 'Status alterado' },
      { id: 'item_moved', label: 'Item movido' },
      { id: 'scheduled', label: 'Agendado' },
    ],
  },
  {
    id: 'condition',
    icon: 'call_split',
    label: 'Condições',
    items: [
      { id: 'text_contains', label: 'Texto contém' },
      { id: 'status_equals', label: 'Status igual a' },
      { id: 'assigned_to', label: 'Atribuído a' },
      { id: 'priority_is', label: 'Prioridade é' },
      { id: 'has_label', label: 'Tem etiqueta' },
    ],
  },
  {
    id: 'action',
    icon: 'flash_on',
    label: 'Ações',
    items: [
      { id: 'send_message', label: 'Enviar mensagem' },
      { id: 'change_status', label: 'Mudar status' },
      { id: 'assign_agent', label: 'Atribuir usuário' },
      { id: 'add_label', label: 'Adicionar etiqueta' },
      { id: 'move_to_column', label: 'Mover para coluna' },
      { id: 'change_priority', label: 'Alterar prioridade' },
      { id: 'send_notification', label: 'Enviar notificação' },
    ],
  },
];

// Métodos
const toggleCategory = categoryId => {
  if (selectedCategory.value === categoryId) {
    selectedCategory.value = null;
  } else {
    selectedCategory.value = categoryId;
  }
};

const addNodeToFlow = (category, itemId) => {
  const nodeType = category.id; // trigger, condition, action
  const data = {
    type: itemId,
    label: category.items.find(i => i.id === itemId).label,
  };

  // Adicionar nó usando o helper
  addNode(store, { type: nodeType, data });

  // Feedback visual
  console.log(`Elemento ${itemId} adicionado`);
};

// Getters do Vuex para histórico de ações
const canUndo = computed(() => store.getters['automationFlow/canUndo']);
const canRedo = computed(() => store.getters['automationFlow/canRedo']);

// Ações de histórico
const undo = () => {
  store.commit('automationFlow/undo');
};

const redo = () => {
  store.commit('automationFlow/redo');
};
</script>

<template>
  <div class="flow-toolbar-container">
    <!-- Cabeçalho da barra de ferramentas -->
    <div class="toolbar-header">
      <h3 class="toolbar-title">Ferramentas</h3>

      <!-- Controles de histórico -->
      <div class="history-controls">
        <button
          class="control-button"
          :disabled="!canUndo"
          title="Desfazer"
          @click="undo"
        >
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
            <path d="M3 10h10a6 6 0 0 1 0 12H8" />
            <path d="M7 10L3 6l4-4" />
          </svg>
        </button>
        <button
          class="control-button"
          :disabled="!canRedo"
          title="Refazer"
          @click="redo"
        >
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
            <path d="M21 10h-10a6 6 0 0 0 0 12h5" />
            <path d="M17 10l4-4-4-4" />
          </svg>
        </button>
      </div>
    </div>

    <!-- Botões de ação rápida -->
    <div class="quick-actions">
      <button
        class="quick-action-button trigger-button"
        title="Adicionar Trigger: Item Criado"
        @click="addNodeToFlow(categories[0], 'item_created')"
      >
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
          <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
        </svg>
        <span>Item Criado</span>
      </button>
      <button
        class="quick-action-button action-button"
        title="Adicionar Ação: Enviar Mensagem"
        @click="addNodeToFlow(categories[2], 'send_message')"
      >
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
          <path d="M22 2L11 13" />
          <path d="M22 2l-7 20-4-9-9-4 20-7z" />
        </svg>
        <span>Enviar Mensagem</span>
      </button>
      <button
        class="quick-action-button condition-button"
        title="Adicionar Condição: Status Igual"
        @click="addNodeToFlow(categories[1], 'status_equals')"
      >
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
          <path d="M6 9l6 6 6-6" />
        </svg>
        <span>Verificar Status</span>
      </button>
    </div>

    <!-- Categorias de nós -->
    <div class="tools-section">
      <h4 class="section-title">Itens</h4>

      <div
        v-for="category in categories"
        :key="category.id"
        class="tool-category"
      >
        <div
          class="category-header"
          :class="{ active: selectedCategory === category.id }"
          @click="toggleCategory(category.id)"
        >
          <div class="category-icon-wrapper" :class="category.id">
            <!-- Disparadores (Trigger) -->
            <svg
              v-if="category.id === 'trigger'"
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
              <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
            </svg>

            <!-- Condições (Condition) -->
            <svg
              v-else-if="category.id === 'condition'"
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
              <path d="M6 9l6 6 6-6" />
            </svg>

            <!-- Ações (Action) -->
            <svg
              v-else-if="category.id === 'action'"
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
              <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
            </svg>
          </div>

          <span class="category-label">{{ category.label }}</span>

          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="expand-icon"
            :class="{ expanded: selectedCategory === category.id }"
          >
            <polyline points="6 9 12 15 18 9" />
          </svg>
        </div>

        <div v-if="selectedCategory === category.id" class="category-items">
          <div
            v-for="item in category.items"
            :key="item.id"
            class="item"
            @click="addNodeToFlow(category, item.id)"
          >
            <div class="item-content">
              <div class="item-icon" :class="item.id">
                <!-- Ícones específicos para cada tipo de item poderiam ser adicionados aqui -->
              </div>
              <span>{{ item.label }}</span>
            </div>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="add-icon"
            >
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.flow-toolbar-container {
  @apply border-l border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800;
  display: flex;
  flex-direction: column;
  width: 280px;
  overflow-y: auto;
}

.toolbar-header {
  @apply p-3 flex items-center justify-between border-b border-slate-200 dark:border-slate-700;
}

.toolbar-title {
  @apply text-sm font-medium text-slate-800 dark:text-slate-200;
}

.history-controls {
  @apply flex gap-1;
}

.control-button {
  @apply p-1.5 rounded-md hover:bg-slate-100 dark:hover:bg-slate-700
    text-slate-500 dark:text-slate-400 transition-colors;

  &:disabled {
    @apply opacity-40 cursor-not-allowed hover:bg-transparent dark:hover:bg-transparent;
  }
}

.quick-actions {
  @apply px-3 py-3 flex flex-col gap-1.5;
  border-bottom: 1px solid #e2e8f0;

  .quick-action-button {
    @apply flex items-center gap-2 px-3 py-2 rounded-md text-sm
      transition-colors;

    &.trigger-button {
      @apply bg-amber-100 dark:bg-amber-900/30 text-amber-900 dark:text-amber-100
        hover:bg-amber-200 dark:hover:bg-amber-800/40;

      svg {
        @apply text-amber-700 dark:text-amber-400;
      }
    }

    &.condition-button {
      @apply bg-woot-400 dark:bg-woot-400 text-purple-900 dark:text-purple-100;

      svg {
        @apply text-purple-700 dark:text-purple-400;
      }
    }

    &.action-button {
      @apply bg-woot-400 dark:bg-woot-400 text-woot-900 dark:text-woot-100;

      svg {
        @apply text-woot-700 dark:text-woot-400;
      }
    }
  }
}

.section-title {
  @apply px-3 py-2 text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider;
}

.tools-section {
  @apply flex-1 overflow-y-auto pb-3;
}

.tool-category {
  @apply mx-3 mb-1 rounded-md overflow-hidden bg-white dark:bg-slate-800
    border border-slate-200 dark:border-slate-700;
}

.category-header {
  @apply flex items-center p-2.5 cursor-pointer
    hover:bg-slate-50 dark:hover:bg-slate-700;

  &.active {
    @apply bg-slate-50 dark:bg-slate-700;
  }
}

.category-icon-wrapper {
  @apply flex items-center justify-center w-6 h-6 rounded-md mr-2;

  &.trigger {
    @apply bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400;
  }

  &.condition {
    @apply bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400;
  }

  &.action {
    @apply bg-woot-100 dark:bg-woot-900/30 text-woot-600 dark:text-woot-400;
  }
}

.category-label {
  @apply text-sm font-medium text-slate-700 dark:text-slate-300 flex-grow;
}

.expand-icon {
  @apply transition-transform text-slate-400 dark:text-slate-500;

  &.expanded {
    @apply rotate-180;
  }
}

.category-items {
  @apply border-t border-slate-200 dark:border-slate-700 divide-y divide-slate-100 dark:divide-slate-800;
}

.item {
  @apply flex items-center justify-between p-2.5 cursor-pointer
    hover:bg-slate-50 dark:hover:bg-slate-700;

  .item-content {
    @apply flex items-center;
  }

  .item-icon {
    @apply w-2 h-2 rounded-full mr-2;

    &.message_received,
    &.send_message {
      @apply bg-green-500;
    }

    &.item_created,
    &.change_status {
      @apply bg-woot-500;
    }

    &.status_changed,
    &.status_equals {
      @apply bg-purple-500;
    }

    &.item_moved,
    &.move_to_column {
      @apply bg-amber-500;
    }
  }

  span {
    @apply text-sm text-slate-700 dark:text-slate-300;
  }

  .add-icon {
    @apply text-slate-400 dark:text-slate-500;
  }
}
</style>
