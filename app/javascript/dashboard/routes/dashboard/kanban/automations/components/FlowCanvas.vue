<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useStore } from 'vuex';
import BaseNode from './nodes/BaseNode.vue';
import TriggerNode from './nodes/TriggerNode.vue';
import ActionNode from './nodes/ActionNode.vue';
import ConditionNode from './nodes/ConditionNode.vue';
import { calculateConnectionPath } from '../utils/flowPositioning';
import NodeEditor from './editors/NodeEditor.vue';

const props = defineProps({
  isLoading: Boolean,
});

const store = useStore();
const canvasRef = ref(null);
const panOffset = ref({ x: 0, y: 0 });
const scale = ref(1);
const isDragging = ref(false);
const startPanPosition = ref({ x: 0, y: 0 });
const selectedNodeId = ref(null);

// Propriedades para controlar o arrasto de nós
const draggingNodeId = ref(null);
const nodeStartPosition = ref({ x: 0, y: 0 });
const dragStartCoords = ref({ x: 0, y: 0 });

// Estado para o editor de nós
const showNodeEditor = ref(false);
const selectedNodeIdForEdit = ref(null);

// Obter nós e conexões do store - correção do namespace
const nodes = computed(() => store.state.automationFlow?.flow?.nodes || []);
const connections = computed(
  () => store.state.automationFlow?.flow?.connections || []
);

// Calcular caminhos das conexões
const connectionPaths = computed(() => {
  if (!connections.value || !nodes.value) return [];

  return connections.value
    .map(connection => {
      const sourceNode = nodes.value.find(
        node => node.id === connection.source
      );
      const targetNode = nodes.value.find(
        node => node.id === connection.target
      );

      if (!sourceNode || !targetNode) return null;

      const result = calculateConnectionPath(
        sourceNode,
        targetNode,
        connection.sourceHandle,
        connection.targetHandle
      );

      return {
        id: connection.id,
        path: result.path,
        labelPosition: result.labelPosition,
        label: connection.label,
        animated: connection.animated,
      };
    })
    .filter(Boolean);
});

// Adicionar computeds para a conexão sendo arrastada
const dragConnection = computed(
  () => store.state.automationFlow.dragConnection
);
const dragConnectionActive = computed(() => dragConnection.value.active);

const dragConnectionPath = computed(() => {
  if (!dragConnectionActive.value) return '';

  // Encontrar o nó de origem/destino
  const node = nodes.value.find(n => n.id === dragConnection.value.nodeId);
  if (!node) return '';

  // Calcular ponto de origem baseado no handle
  const isSource = dragConnection.value.handleType === 'source';

  // Dimensões dos nós e conectores
  const nodeWidth = 240;
  const nodeHeight = 100;
  const handleRadius = 6;

  // Calcular posição inicial da conexão
  let startX, startY;
  if (isSource) {
    // Se for do conector de saída (direito), usar a borda direita + raio
    startX = node.position.x + nodeWidth + handleRadius;
  } else {
    // Se for do conector de entrada (esquerdo), usar a borda esquerda - raio
    startX = node.position.x - handleRadius;
  }

  // Altura é sempre o meio do nó
  startY = node.position.y + nodeHeight / 2;

  // Ponto do mouse ajustado para pan e zoom
  const canvasRect = canvasRef.value?.getBoundingClientRect() || {
    left: 0,
    top: 0,
  };

  const mouseX =
    (dragConnection.value.position.x - canvasRect.left - panOffset.value.x) /
    scale.value;
  const mouseY =
    (dragConnection.value.position.y - canvasRect.top - panOffset.value.y) /
    scale.value;

  // Curva Bezier mais suave
  const distance = Math.abs(mouseX - startX);
  const curveDistance = Math.min(distance * 0.5, 150);

  // Gerar caminho SVG
  return isSource
    ? `M${startX},${startY} C${startX + curveDistance},${startY} ${mouseX - curveDistance},${mouseY} ${mouseX},${mouseY}`
    : `M${mouseX},${mouseY} C${mouseX + curveDistance},${mouseY} ${startX - curveDistance},${startY} ${startX},${startY}`;
});

// Manipuladores de eventos
const startPan = event => {
  // Verificar se o clique foi no canvas (corrigir seletor)
  if (event.button !== 0) return; // Simplificar para apenas botão esquerdo

  // Não iniciar drag em elementos filhos que possam ter seus próprios handlers
  const isNode = event.target.closest('.node-container');
  if (isNode) return;

  isDragging.value = true;
  startPanPosition.value = {
    x: event.clientX - panOffset.value.x,
    y: event.clientY - panOffset.value.y,
  };

  // Adicionar classe para mudar o cursor durante o arrasto
  document.body.classList.add('dragging');
  event.preventDefault();
};

const doPan = event => {
  if (!isDragging.value) return;

  // Calcular a nova posição
  panOffset.value = {
    x: event.clientX - startPanPosition.value.x,
    y: event.clientY - startPanPosition.value.y,
  };
};

const endPan = () => {
  if (isDragging.value) {
    isDragging.value = false;
    document.body.classList.remove('dragging');
  }
};

const handleMouseWheel = event => {
  // Apenas faça zoom se a tecla Ctrl estiver pressionada
  if (!event.ctrlKey) return;

  // Zoom in/out com a roda do mouse
  const delta = event.deltaY > 0 ? -0.1 : 0.1;
  const newScale = Math.min(Math.max(scale.value + delta, 0.5), 2);

  // Ajustar o zoom mantendo o ponto sob o cursor
  if (newScale !== scale.value) {
    const rect = canvasRef.value.getBoundingClientRect();
    const mouseX = event.clientX - rect.left;
    const mouseY = event.clientY - rect.top;

    const oldWorldX = (mouseX - panOffset.value.x) / scale.value;
    const oldWorldY = (mouseY - panOffset.value.y) / scale.value;

    const newWorldX = (mouseX - panOffset.value.x) / newScale;
    const newWorldY = (mouseY - panOffset.value.y) / newScale;

    panOffset.value.x += (newWorldX - oldWorldX) * newScale;
    panOffset.value.y += (newWorldY - oldWorldY) * newScale;

    scale.value = newScale;
  }

  event.preventDefault();
};

// Evento de clique no canvas (deselecionar nós)
const handleCanvasClick = event => {
  if (event.target === canvasRef.value) {
    selectedNodeId.value = null;
    store.commit('automationFlow/setSelectedNode', null);
  }
};

// Setup e cleanup dos listeners de eventos
onMounted(() => {
  if (canvasRef.value) {
    // Adicionar todos os listeners necessários ao canvas
    canvasRef.value.addEventListener('wheel', handleMouseWheel, {
      passive: false,
    });
    canvasRef.value.addEventListener('mousedown', startPan);
    document.addEventListener('mousemove', doPan);
    document.addEventListener('mouseup', endPan);
    document.addEventListener('mouseleave', endPan);
  }
});

onUnmounted(() => {
  if (canvasRef.value) {
    // Remover todos os listeners para prevenir memory leaks
    canvasRef.value.removeEventListener('wheel', handleMouseWheel);
    canvasRef.value.removeEventListener('mousedown', startPan);
    document.removeEventListener('mousemove', doPan);
    document.removeEventListener('mouseup', endPan);
    document.removeEventListener('mouseleave', endPan);
  }
});

// Método para selecionar um nó
const selectNode = nodeId => {
  selectedNodeId.value = nodeId;
  store.commit('automationFlow/setSelectedNode', nodeId);
};

// Centralize o flow no canvas
const centerFlow = () => {
  if (!nodes.value.length) return;

  // Calcular o centro do flow
  let minX = Infinity,
    maxX = -Infinity,
    minY = Infinity,
    maxY = -Infinity;

  nodes.value.forEach(node => {
    minX = Math.min(minX, node.position.x);
    maxX = Math.max(maxX, node.position.x + 200); // Largura aproximada
    minY = Math.min(minY, node.position.y);
    maxY = Math.max(maxY, node.position.y + 100); // Altura aproximada
  });

  // Centralizar
  const canvasWidth = canvasRef.value?.clientWidth || 800;
  const canvasHeight = canvasRef.value?.clientHeight || 600;

  const flowWidth = maxX - minX;
  const flowHeight = maxY - minY;

  panOffset.value = {
    x: (canvasWidth - flowWidth * scale.value) / 2 - minX * scale.value,
    y: (canvasHeight - flowHeight * scale.value) / 2 - minY * scale.value,
  };
};

// Centralizar automaticamente na montagem, após o carregamento
watch(
  () => props.isLoading,
  loading => {
    if (!loading) {
      setTimeout(centerFlow, 100);
    }
  }
);

// Implementação completa do drag de nodes
const startNodeDrag = (event, nodeId) => {
  event.stopPropagation(); // Impedir que o evento chegue ao canvas
  console.log('startNodeDrag chamado para o node:', nodeId);

  // Encontrar o nó no array
  const node = nodes.value.find(n => n.id === nodeId);
  if (!node) {
    console.error('Node não encontrado:', nodeId);
    return;
  }

  // Registrar que estamos arrastando este nó
  draggingNodeId.value = nodeId;

  // Salvar a posição inicial do nó
  nodeStartPosition.value = { ...node.position };

  // Salvar a posição inicial do mouse
  dragStartCoords.value = { x: event.clientX, y: event.clientY };

  console.log('Iniciando drag do node:', {
    nodeId,
    startPos: nodeStartPosition.value,
    mouseStart: dragStartCoords.value,
  });

  // Adicionar classe visual
  document.body.classList.add('node-dragging');

  // Adicionar event listeners temporários para o arrasto
  document.addEventListener('mousemove', dragNode);
  document.addEventListener('mouseup', endNodeDrag);
};

// Função para atualizar a posição do nó durante o arrasto
const dragNode = event => {
  if (!draggingNodeId.value) return;

  // Calcular deslocamento do mouse
  const dx = event.clientX - dragStartCoords.value.x;
  const dy = event.clientY - dragStartCoords.value.y;

  // Encontrar o nó que está sendo arrastado
  const nodeIndex = nodes.value.findIndex(n => n.id === draggingNodeId.value);
  if (nodeIndex === -1) return;

  // Calcular nova posição
  const newX = nodeStartPosition.value.x + dx / scale.value;
  const newY = nodeStartPosition.value.y + dy / scale.value;

  // Atualizar a posição do nó no store, sem adicionar ao histórico durante o arrasto
  store.commit('automationFlow/updateNode', {
    nodeId: draggingNodeId.value,
    updates: { position: { x: newX, y: newY } },
    addToHistory: false, // Não adicionar ao histórico durante o arrasto
  });
};

// Adicionar um registro no histórico apenas quando o arrasto termina
const endNodeDrag = () => {
  if (!draggingNodeId.value) return;

  // Adicionar um único registro no histórico ao finalizar o arrasto
  store.commit('automationFlow/recordCurrentState');

  // Limpar estado
  draggingNodeId.value = null;

  // Remover event listeners
  document.removeEventListener('mousemove', dragNode);
  document.removeEventListener('mouseup', endNodeDrag);

  // Remover classe visual
  document.body.classList.remove('node-dragging');
};

const getNodeComponent = type => {
  switch (type) {
    case 'trigger':
      return TriggerNode;
    case 'condition':
      return ConditionNode;
    case 'action':
      return ActionNode;
    default:
      return BaseNode;
  }
};

// Adicionar métodos para manipular os nós
const handleNodeEdit = nodeId => {
  selectedNodeIdForEdit.value = nodeId;
  showNodeEditor.value = true;
};

const handleNodeDuplicate = nodeId => {
  // Implementar lógica para duplicar o nó
  store.dispatch('automationFlow/duplicateNode', nodeId);
};

const handleNodeDelete = nodeId => {
  // Implementar lógica para excluir o nó
  store.commit('automationFlow/removeNode', nodeId);
};

// Métodos para o editor de nós
const closeNodeEditor = () => {
  showNodeEditor.value = false;
  selectedNodeIdForEdit.value = null;
};

const handleNodeEditorSave = () => {
  closeNodeEditor();
  // Adicionar notificação de sucesso se desejar
};
</script>

<template>
  <div class="canvas-wrapper">
    <div ref="canvasRef" class="flow-canvas" @click="handleCanvasClick">
      <div
        class="flow-container"
        :style="{
          transform: `translate(${panOffset.x}px, ${panOffset.y}px) scale(${scale})`,
          transformOrigin: '0 0',
        }"
      >
        <!-- Conexões -->
        <svg class="connections-layer">
          <g v-for="connection in connectionPaths" :key="connection.id">
            <path
              :d="connection.path"
              class="connection-path"
              :class="{ animated: connection.animated }"
            />
            <text
              v-if="connection.label"
              :x="connection.labelPosition?.x"
              :y="connection.labelPosition?.y"
              class="connection-label"
            >
              {{ connection.label }}
            </text>
          </g>

          <!-- Linha de conexão sendo arrastada -->
          <path
            v-if="dragConnectionActive"
            :d="dragConnectionPath"
            class="drag-connection-path"
          />
        </svg>

        <!-- Nós -->
        <component
          v-for="node in nodes"
          :key="node.id"
          :is="getNodeComponent(node.type)"
          :node="node"
          :selected="node.id === selectedNodeId"
          :data-node-id="node.id"
          @click.stop="selectNode(node.id)"
          @mousedown.stop="startNodeDrag($event, node.id)"
          @edit="handleNodeEdit(node.id)"
          @duplicate="handleNodeDuplicate(node.id)"
          @delete="handleNodeDelete(node.id)"
        />
      </div>

      <!-- Controles de zoom -->
    </div>

    <!-- Modal de edição de nó -->
    <NodeEditor
      :show="showNodeEditor"
      :nodeId="selectedNodeIdForEdit"
      @close="closeNodeEditor"
      @save="handleNodeEditorSave"
    />
  </div>
</template>

<style lang="scss" scoped>
.flow-canvas {
  position: relative;
  width: 100%;
  height: 100%;
  overflow: hidden;
  background-color: #f5f8fa;
  user-select: none;

  &:active {
    cursor: grabbing;
  }

  .flow-container {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    will-change: transform;
  }

  .connections-layer {
    @apply absolute top-0 left-0 w-full h-full;
    pointer-events: none;
    z-index: 1;

    .connection-path {
      fill: none;
      stroke: #94a3b8;
      stroke-width: 2px;

      &.animated {
        stroke-dasharray: 5;
        animation: dash 1s linear infinite;
      }
    }

    .connection-label {
      fill: #475569;
      font-size: 12px;
      text-anchor: middle;
      dominant-baseline: central;
      pointer-events: none;
    }
  }

  .canvas-controls {
    @apply absolute top-0 right-0 p-4;
  }

  .loading-overlay {
    @apply absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/80;
    z-index: 10;

    .spinner {
      @apply w-10 h-10 border-4 border-slate-300 dark:border-slate-700 rounded-full;
      border-top-color: #3b82f6;
      animation: spin 1s linear infinite;
    }
  }
}

@keyframes dash {
  to {
    stroke-dashoffset: 10;
  }
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.canvas-wrapper {
  width: 100%;
  height: 100%;
  overflow: auto;
  position: relative;
}

/* Estilo para o cursor quando estiver arrastando */
:global(body.dragging) {
  cursor: grabbing !important;
}

/* Cursor padrão quando não estiver arrastando */
.flow-canvas {
  cursor: grab;
}

.drag-connection-path {
  fill: none;
  stroke: #3b82f6;
  stroke-width: 2px;
  stroke-dasharray: 5;
  animation: dash 1s linear infinite;
  pointer-events: none;
}
</style>
