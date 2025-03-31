import { Position } from '@vue-flow/core';

const state = {
  currentAutomation: null,
  isEditing: false,
  flowNodes: [],
  flowEdges: [],
};

const getters = {
  getCurrentAutomation: $state => $state.currentAutomation,
  isEditing: $state => $state.isEditing,
  getFlowNodes: $state => $state.flowNodes,
  getFlowEdges: $state => $state.flowEdges,
};

const mutations = {
  SET_CURRENT_AUTOMATION(state, automation) {
    state.currentAutomation = automation;
  },
  SET_IS_EDITING(state, isEditing) {
    state.isEditing = isEditing;
  },
  SET_FLOW_NODES(state, nodes) {
    state.flowNodes = nodes;
  },
  SET_FLOW_EDGES(state, edges) {
    state.flowEdges = edges;
  },
  ADD_NODE(state, node) {
    // Estrutura mínima requerida pelo VueFlow
    const newNode = {
      id: `${node.type}-${Date.now()}`, // id único
      type: `${node.type}Node`, // tipo do nó
      position: {
        x: node.position?.x ?? 250,
        y: node.position?.y ?? state.flowNodes.length * 100 + 50,
      },
      data: node.data || {}, // dados do nó
      // Propriedades básicas do VueFlow
      sourceHandle: null,
      targetHandle: null,
      selected: false,
      dragging: false,
      // Conexões
      connectable: true,
      deletable: true,
      draggable: true,
      selectable: true,
      // Posições dos handles
      sourcePosition: Position.Bottom,
      targetPosition: Position.Top,
    };

    state.flowNodes.push(newNode);
  },
  REMOVE_NODE(state, nodeId) {
    state.flowNodes = state.flowNodes.filter(node => node.id !== nodeId);
    state.flowEdges = state.flowEdges.filter(
      edge => edge.source !== nodeId && edge.target !== nodeId
    );
  },
  UPDATE_NODE_DATA(state, { nodeId, data }) {
    state.flowNodes = state.flowNodes.map(node => {
      if (node.id === nodeId) {
        return {
          ...node,
          data: { ...node.data, ...data },
        };
      }
      return node;
    });
  },
  UPDATE_NODE_POSITION(state, { nodeId, position }) {
    state.flowNodes = state.flowNodes.map(node => {
      if (node.id === nodeId) {
        return {
          ...node,
          position: {
            x: Number(position.x),
            y: Number(position.y),
          },
          dragging: false,
        };
      }
      return node;
    });
  },
};

const actions = {
  setCurrentAutomation({ commit }, automation) {
    commit('SET_CURRENT_AUTOMATION', automation);
    commit('SET_IS_EDITING', !!automation);

    // Converter automação para formato de fluxo
    if (automation) {
      const nodes = [];
      const edges = [];

      // Adicionar nó de trigger
      nodes.push({
        id: 'trigger',
        type: 'triggerNode',
        position: { x: 250, y: 50 },
        data: {
          type: automation.trigger.type,
          column: automation.trigger.column,
          inactivity_period: automation.trigger.inactivity_period,
        },
      });

      // Adicionar nós de condição
      if (automation.conditions && automation.conditions.length > 0) {
        automation.conditions.forEach((condition, index) => {
          const nodeId = `condition-${index}`;
          nodes.push({
            id: nodeId,
            type: 'conditionNode',
            position: { x: 250, y: 150 + index * 100 },
            data: { ...condition },
          });

          // Conectar ao nó anterior
          const sourceId = index === 0 ? 'trigger' : `condition-${index - 1}`;
          edges.push({
            id: `edge-${sourceId}-${nodeId}`,
            source: sourceId,
            target: nodeId,
          });
        });
      }

      // Adicionar nós de ação
      if (automation.actions && automation.actions.length > 0) {
        const lastConditionIndex = automation.conditions
          ? automation.conditions.length - 1
          : -1;
        const lastConditionId =
          lastConditionIndex >= 0
            ? `condition-${lastConditionIndex}`
            : 'trigger';

        automation.actions.forEach((action, index) => {
          const nodeId = `action-${index}`;
          nodes.push({
            id: nodeId,
            type: 'actionNode',
            position: {
              x: 250,
              y: 250 + (lastConditionIndex + 1) * 100 + index * 100,
            },
            data: { ...action },
          });

          // Conectar ao nó anterior
          const sourceId =
            index === 0 ? lastConditionId : `action-${index - 1}`;
          edges.push({
            id: `edge-${sourceId}-${nodeId}`,
            source: sourceId,
            target: nodeId,
          });
        });
      }

      commit('SET_FLOW_NODES', nodes);
      commit('SET_FLOW_EDGES', edges);
    } else {
      // Inicializar com um nó de trigger vazio
      commit('SET_FLOW_NODES', [
        {
          id: 'trigger',
          type: 'triggerNode',
          position: { x: 250, y: 50 },
          data: {
            type: 'item_created',
            column: 'all',
          },
        },
      ]);
      commit('SET_FLOW_EDGES', []);
    }
  },

  updateFlowNodes({ commit }, nodes) {
    commit('SET_FLOW_NODES', nodes);
  },

  updateFlowEdges({ commit }, edges) {
    commit('SET_FLOW_EDGES', edges);
  },

  addNode({ commit }, node) {
    commit('ADD_NODE', node);
  },

  removeNode({ commit }, nodeId) {
    commit('REMOVE_NODE', nodeId);
  },

  updateNodeData({ commit }, payload) {
    commit('UPDATE_NODE_DATA', payload);
  },

  // Converter o fluxo de volta para o formato de automação
  buildAutomationFromFlow({ state: $state }) {
    const triggerNode = $state.flowNodes.find(
      node => node.type === 'triggerNode'
    );
    const conditionNodes = $state.flowNodes.filter(
      node => node.type === 'conditionNode'
    );
    const actionNodes = $state.flowNodes.filter(
      node => node.type === 'actionNode'
    );

    const automation = {
      ...($state.currentAutomation || {}),
      trigger: triggerNode
        ? triggerNode.data
        : { type: 'item_created', column: 'all' },
      conditions: conditionNodes.map(node => node.data),
      actions: actionNodes.map(node => node.data),
    };

    return automation;
  },

  resetEditor({ commit }) {
    commit('SET_CURRENT_AUTOMATION', null);
    commit('SET_IS_EDITING', false);
    commit('SET_FLOW_NODES', []);
    commit('SET_FLOW_EDGES', []);
  },

  clearCurrentAutomation({ commit }) {
    commit('SET_CURRENT_AUTOMATION', null);
    commit('SET_FLOW_NODES', []);
    commit('SET_FLOW_EDGES', []);
  },

  setFlowNodes({ commit }, nodes) {
    commit('SET_FLOW_NODES', nodes);
  },

  updateFlowNodes({ commit, state }, changes) {
    // Implementação básica
    commit('SET_FLOW_NODES', [...state.flowNodes]);
  },

  setFlowEdges({ commit }, edges) {
    commit('SET_FLOW_EDGES', edges);
  },

  updateFlowEdges({ commit, state }, changes) {
    // Implementação básica
    commit('SET_FLOW_EDGES', [...state.flowEdges]);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
