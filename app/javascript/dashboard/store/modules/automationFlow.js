import KanbanAutomationsAPI from '../../api/kanbanAutomations';

// Módulo Vuex para o fluxo de automação
export default {
  namespaced: true,

  state: {
    flow: {
      nodes: [],
      connections: [],
    },
    selectedNodeId: null,
    draggedConnectionId: null,
    history: [],
    historyIndex: -1,
    automations: [],
    dragConnection: {
      active: false,
      nodeId: null,
      handleType: null,
      position: { x: 0, y: 0 },
    },
  },

  getters: {
    getNodes: state => state.flow.nodes,
    getConnections: state => state.flow.connections,
    getSelectedNode: state => {
      return state.selectedNodeId
        ? state.flow.nodes.find(node => node.id === state.selectedNodeId)
        : null;
    },
    canUndo: state => state.historyIndex > 0,
    canRedo: state => state.historyIndex < state.history.length - 1,
    getAutomations: state => {
      return state.automations || [];
    },
    getAutomationById: state => id => {
      return state.automations.find(automation => automation.id === id);
    },
  },

  mutations: {
    setFlow(state, flow) {
      state.flow = { ...flow };
      // Adicionar à história
      state.history = state.history.slice(0, state.historyIndex + 1);
      state.history.push(JSON.stringify(state.flow));
      state.historyIndex = state.history.length - 1;
    },

    setNodes(state, nodes) {
      state.flow.nodes = [...nodes];
    },

    addNode(state, node) {
      state.flow.nodes.push(node);
      // Adicionar à história
      state.history = state.history.slice(0, state.historyIndex + 1);
      state.history.push(JSON.stringify(state.flow));
      state.historyIndex = state.history.length - 1;
    },

    updateNode(state, { nodeId, updates, addToHistory = true }) {
      const nodeIndex = state.flow.nodes.findIndex(node => node.id === nodeId);
      if (nodeIndex >= 0) {
        // Criar uma cópia atualizada do nó
        const updatedNode = { ...state.flow.nodes[nodeIndex], ...updates };

        // Se estamos atualizando a posição, garantir que ela seja atualizada corretamente
        if (updates.position) {
          updatedNode.position = {
            ...state.flow.nodes[nodeIndex].position,
            ...updates.position,
          };
        }

        // Atualizar o nó no array
        state.flow.nodes = [
          ...state.flow.nodes.slice(0, nodeIndex),
          updatedNode,
          ...state.flow.nodes.slice(nodeIndex + 1),
        ];

        // Adicionar à história apenas se addToHistory for true
        if (addToHistory) {
          state.history = state.history.slice(0, state.historyIndex + 1);
          state.history.push(JSON.stringify(state.flow));
          state.historyIndex = state.history.length - 1;
        }
      }
    },

    removeNode(state, nodeId) {
      state.flow.nodes = state.flow.nodes.filter(node => node.id !== nodeId);
      // Remover também as conexões relacionadas
      state.flow.connections = state.flow.connections.filter(
        conn => conn.source !== nodeId && conn.target !== nodeId
      );
      // Adicionar à história
      state.history = state.history.slice(0, state.historyIndex + 1);
      state.history.push(JSON.stringify(state.flow));
      state.historyIndex = state.history.length - 1;
    },

    addConnection(state, connection) {
      state.flow.connections.push(connection);
      // Adicionar à história
      state.history = state.history.slice(0, state.historyIndex + 1);
      state.history.push(JSON.stringify(state.flow));
      state.historyIndex = state.history.length - 1;
    },

    removeConnection(state, connectionId) {
      state.flow.connections = state.flow.connections.filter(
        conn => conn.id !== connectionId
      );
      // Adicionar à história
      state.history = state.history.slice(0, state.historyIndex + 1);
      state.history.push(JSON.stringify(state.flow));
      state.historyIndex = state.history.length - 1;
    },

    setSelectedNode(state, nodeId) {
      state.selectedNodeId = nodeId;
    },

    setDraggedConnection(state, connectionId) {
      state.draggedConnectionId = connectionId;
    },

    undo(state) {
      if (state.historyIndex > 0) {
        state.historyIndex--;
        state.flow = JSON.parse(state.history[state.historyIndex]);
      }
    },

    redo(state) {
      if (state.historyIndex < state.history.length - 1) {
        state.historyIndex++;
        state.flow = JSON.parse(state.history[state.historyIndex]);
      }
    },

    clearHistory(state) {
      state.history = [JSON.stringify(state.flow)];
      state.historyIndex = 0;
    },

    SET_AUTOMATIONS(state, automations) {
      state.automations = automations;
    },

    recordCurrentState(state) {
      state.history = state.history.slice(0, state.historyIndex + 1);
      state.history.push(JSON.stringify(state.flow));
      state.historyIndex = state.history.length - 1;
    },

    startConnectionDrag(state, { nodeId, handleType }) {
      state.dragConnection = {
        active: true,
        nodeId,
        handleType,
        position: { x: 0, y: 0 },
      };
    },

    updateDragPosition(state, position) {
      state.dragConnection.position = position;
    },

    endConnectionDrag(state) {
      state.dragConnection.active = false;
    },
  },

  actions: {
    initFlow({ commit }, initialFlow = null) {
      const defaultFlow = {
        nodes: [
          {
            id: 'trigger-1',
            type: 'trigger',
            position: { x: 250, y: 50 },
            data: {
              label: 'Quando mensagem recebida',
              type: 'message_received',
            },
          },
        ],
        connections: [],
      };

      commit('setFlow', initialFlow || defaultFlow);
      commit('clearHistory');
    },

    updateNodePosition({ commit, state }, { nodeId, position }) {
      commit('updateNode', {
        nodeId,
        updates: { position },
      });
    },

    updateNodeData({ commit, state }, { nodeId, data }) {
      commit('updateNode', {
        nodeId,
        updates: { data },
      });
    },

    createNode({ commit, state, getters }, { type, position, data }) {
      const id = `${type}-${Date.now()}`;
      const newNode = {
        id,
        type,
        position,
        data: data || {},
      };

      commit('addNode', newNode);
      return id;
    },

    connectNodes(
      { commit, state },
      {
        sourceId,
        targetId,
        sourceHandle = 'bottom',
        targetHandle = 'top',
        label = '',
      }
    ) {
      const id = `conn-${sourceId}-${targetId}-${Date.now()}`;

      const connection = {
        id,
        source: sourceId,
        target: targetId,
        sourceHandle,
        targetHandle,
        label,
        animated: false,
      };

      commit('addConnection', connection);
      return id;
    },

    duplicateNode({ commit, state, dispatch }, nodeId) {
      const node = state.flow.nodes.find(n => n.id === nodeId);
      if (!node) return null;

      // Criar uma cópia com novo ID e posição levemente deslocada
      const newPosition = {
        x: node.position.x + 20,
        y: node.position.y + 20,
      };

      return dispatch('createNode', {
        type: node.type,
        position: newPosition,
        data: { ...node.data },
      });
    },

    async fetchAutomations({ commit }) {
      try {
        let automations = [];
        try {
          const response = await KanbanAutomationsAPI.get();
          automations = response.data || [];
        } catch (error) {
          console.error('Erro ao chamar API de automações:', error);
          automations = [];
        }

        commit('SET_AUTOMATIONS', automations);
        return automations;
      } catch (error) {
        console.error('Erro ao buscar automações:', error);
        commit('SET_AUTOMATIONS', []);
        return [];
      }
    },

    async fetchAutomation({ commit, state }, id) {
      try {
        const response = await KanbanAutomationsAPI.show(id);
        return response.data;
      } catch (error) {
        console.error('Erro ao buscar automação:', error);
        return state.automations.find(automation => automation.id === id);
      }
    },

    async saveAutomation({ commit, state }, automationData) {
      try {
        if (automationData.id) {
          await KanbanAutomationsAPI.update(automationData.id, automationData);
        } else {
          await KanbanAutomationsAPI.create(automationData);
        }

        // Atualizar o estado com dados reais
        await this.dispatch('automationFlow/fetchAutomations');
        return true;
      } catch (error) {
        console.error('Erro ao salvar automação:', error);
        return false;
      }
    },
  },
};
