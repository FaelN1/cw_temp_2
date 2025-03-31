<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';

const props = defineProps({
  node: {
    type: Object,
    required: true,
  },
  selected: {
    type: Boolean,
    default: false,
  },
  isConnecting: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'click',
  'dragStart',
  'dragEnd',
  'connectStart',
  'connectEnd',
  'mousedown',
  'edit',
  'duplicate',
  'delete',
]);

const store = useStore();
const showMenu = ref(false);

const canHaveInputs = computed(() => {
  return props.node.type !== 'trigger'; // Disparadores não têm entradas
});

const canHaveOutputs = computed(() => {
  return true; // Todos os nós podem ter saídas
});

const toggleMenu = event => {
  event.stopPropagation();
  showMenu.value = !showMenu.value;

  // Fechar o menu quando clicar fora
  if (showMenu.value) {
    setTimeout(() => {
      window.addEventListener('click', closeMenu);
    }, 0);
  }
};

const closeMenu = () => {
  showMenu.value = false;
  window.removeEventListener('click', closeMenu);
};

// Iniciar conexão arrastando de um handle
const startDragConnection = type => {
  const connectionData = {
    nodeId: props.node.id,
    handleType: type,
  };
  store.commit('automationFlow/startConnectionDrag', connectionData);

  // Adicionar listeners globais
  document.addEventListener('mousemove', dragConnection);
  document.addEventListener('mouseup', endConnectionDrag);
};

// Atualizar a posição da conexão durante o arrasto
const dragConnection = event => {
  // Atualizar a posição da linha temporária
  const x = event.clientX;
  const y = event.clientY;
  store.commit('automationFlow/updateDragPosition', { x, y });
};

// Finalizar o arrasto da conexão
const endConnectionDrag = event => {
  // Remover os event listeners
  document.removeEventListener('mousemove', dragConnection);
  document.removeEventListener('mouseup', endConnectionDrag);

  try {
    // Verificar se o mouse está sobre outro nó
    const target = event.target;
    const handleElement = target.closest('.handle');

    if (handleElement) {
      // Se o mouse estiver sobre um handle, criar a conexão
      const nodeElement = handleElement.closest('.node-container');
      if (nodeElement) {
        const nodeId = nodeElement.getAttribute('data-node-id');

        if (!nodeId) {
          console.warn('Node ID não encontrado no elemento DOM');
          store.commit('automationFlow/endConnectionDrag');
          return;
        }

        const handleType = handleElement.classList.contains('handle-left')
          ? 'target'
          : 'source';

        // Evitar conectar mesmo tipo de handle
        const dragData = store.state.automationFlow.dragConnection;
        if (!dragData || !dragData.active) {
          console.warn('Dados de arrasto inválidos ou já finalizados');
          store.commit('automationFlow/endConnectionDrag');
          return;
        }

        if (dragData.handleType !== handleType && nodeId !== dragData.nodeId) {
          // Criar conexão no store
          if (dragData.handleType === 'source') {
            store.dispatch('automationFlow/connectNodes', {
              sourceId: dragData.nodeId,
              targetId: nodeId,
              sourceHandle: 'right',
              targetHandle: 'left',
            });
          } else {
            store.dispatch('automationFlow/connectNodes', {
              sourceId: nodeId,
              targetId: dragData.nodeId,
              sourceHandle: 'right',
              targetHandle: 'left',
            });
          }
        }
      }
    }
  } catch (error) {
    console.error('Erro ao finalizar conexão:', error);
  } finally {
    // Sempre finalizar o arrasto, mesmo em caso de erro
    store.commit('automationFlow/endConnectionDrag');
  }
};

const handleClick = event => {
  emit('click', event, props.node);
};

const handleDragStart = event => {
  emit('dragStart', event, props.node);
};

const handleDragEnd = event => {
  emit('dragEnd', event, props.node);
};

const handleConnectStart = (event, handle) => {
  emit('connectStart', event, props.node, handle);
};

const handleConnectEnd = (event, handle) => {
  emit('connectEnd', event, props.node, handle);
};

// Handler para edição local antes de emitir o evento
const handleEdit = event => {
  event.stopPropagation();
  closeMenu();
  emit('edit');
};
</script>

<template>
  <div
    class="node-container"
    :class="{ selected: selected }"
    :style="{
      left: `${node.position.x}px`,
      top: `${node.position.y}px`,
    }"
    @click="$emit('click', $event)"
    @dblclick="$emit('edit')"
    @mousedown="$emit('mousedown', $event)"
  >
    <div class="node-card" :class="node.type">
      <div class="node-header">
        <div class="node-icon">
          <!-- Ícones específicos por tipo -->
          <svg
            v-if="node.type === 'trigger'"
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

          <svg
            v-else-if="node.type === 'condition'"
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
            <path d="M6 9l6 6 6-6"></path>
          </svg>

          <svg
            v-else-if="node.type === 'action'"
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
            <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
          </svg>
        </div>
        <div class="node-title">
          {{ node.data.label }}
        </div>
        <div class="node-menu" @click.stop="toggleMenu">
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
          >
            <circle cx="12" cy="12" r="1"></circle>
            <circle cx="12" cy="5" r="1"></circle>
            <circle cx="12" cy="19" r="1"></circle>
          </svg>
        </div>
      </div>

      <div class="node-content">
        <slot name="content">
          <!-- Conteúdo específico por tipo de nó será inserido aqui -->
          <div v-if="node.data.description" class="node-description">
            {{ node.data.description }}
          </div>
        </slot>
      </div>

      <!-- Pontos de conexão nos lados -->
      <div class="handle-container">
        <!-- Handle de entrada (esquerda) -->
        <div
          v-if="canHaveInputs"
          class="handle handle-left"
          @mousedown.stop="startDragConnection('target')"
        ></div>

        <!-- Handle de saída (direita) -->
        <div
          v-if="canHaveOutputs"
          class="handle handle-right"
          @mousedown.stop="startDragConnection('source')"
        ></div>
      </div>

      <!-- Menu dropdown -->
      <div v-if="showMenu" class="node-dropdown">
        <div class="dropdown-item" @click="handleEdit">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="12"
            height="12"
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
          <span>Editar</span>
        </div>
        <div class="dropdown-item" @click="$emit('duplicate')">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
            <path
              d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"
            ></path>
          </svg>
          <span>Duplicar</span>
        </div>
        <div class="dropdown-item delete" @click="$emit('delete')">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="12"
            height="12"
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
          <span>Excluir</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.node-container {
  position: absolute;
  user-select: none;
  z-index: 5;
  transition: transform 0.1s;

  &.selected {
    z-index: 10;

    .node-card {
      box-shadow:
        0 0 0 2px #3b82f6,
        0 4px 8px rgba(0, 0, 0, 0.1);
    }
  }

  &:hover {
    .handle {
      opacity: 1;
    }
  }
}

.node-card {
  width: 240px;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  overflow: hidden;

  &.trigger {
    border-top: 3px solid #f59e0b;
  }

  &.condition {
    border-top: 3px solid #8b5cf6;
  }

  &.action {
    border-top: 3px solid #3b82f6;
  }
}

.node-header {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  background-color: #f8fafc;
  border-bottom: 1px solid #e2e8f0;

  .node-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    margin-right: 8px;
    border-radius: 4px;

    .trigger & {
      color: #f59e0b;
    }

    .condition & {
      color: #8b5cf6;
    }

    .action & {
      color: #3b82f6;
    }
  }

  .node-title {
    flex: 1;
    font-weight: 500;
    font-size: 14px;
    color: #334155;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .node-menu {
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    color: #64748b;
    cursor: pointer;

    &:hover {
      background-color: #e2e8f0;
    }
  }
}

.node-content {
  padding: 12px 16px;
  font-size: 13px;
  color: #475569;
  min-height: 20px;

  .node-description {
    margin-bottom: 8px;
  }
}

.handle-container {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
}

.handle {
  position: absolute;
  width: 12px;
  height: 12px;
  background-color: white;
  border: 2px solid #94a3b8;
  border-radius: 50%;
  z-index: 10;
  opacity: 0;
  transition:
    opacity 0.2s,
    background-color 0.2s;
  pointer-events: all;
  cursor: crosshair;

  &:hover {
    background-color: #3b82f6;
    border-color: #3b82f6;
  }

  &.handle-left {
    top: 50%;
    left: -6px;
    transform: translateY(-50%);
  }

  &.handle-right {
    top: 50%;
    right: -6px;
    transform: translateY(-50%);
  }
}

.node-dropdown {
  position: absolute;
  top: 100%;
  right: 10px;
  margin-top: 4px;
  width: 140px;
  background-color: white;
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  z-index: 30;
  overflow: hidden;

  .dropdown-item {
    display: flex;
    align-items: center;
    padding: 8px 12px;
    font-size: 13px;
    color: #475569;
    cursor: pointer;

    svg {
      margin-right: 8px;
    }

    &:hover {
      background-color: #f1f5f9;
    }

    &.delete {
      color: #ef4444;
    }
  }
}
</style>
