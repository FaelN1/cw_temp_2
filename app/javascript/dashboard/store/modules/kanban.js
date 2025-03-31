import types from '../mutation-types';
import KanbanAPI from '../../api/kanban';

const state = {
  isEnabled: false,
  items: [],
  loading: false,
  error: null,
  config: {
    title: window.globalConfig.KANBAN_TITLE || 'Gestor de Pedidos',
    defaultView: 'kanban',
    webhookUrl: '',
    webhookSecret: '',
    autoAssignment: false,
    notificationsEnabled: false,
    supportEmail: '',
    supportPhone: '',
    supportChatHours: '',
    supportChatEnabled: false,
  },
  lastUpdated: null,
};

const getters = {
  isKanbanEnabled: _state => _state.isEnabled,
  getKanbanItems: _state => _state.items,
  isLoading: _state => _state.loading,
  getError: _state => _state.error,
  getKanbanConfig: _state => _state.config,
  getKanbanTitle: _state =>
    window.globalConfig.KANBAN_TITLE || _state.config?.title || 'Kanban',
  getSupportEmail: _state => _state.config?.supportEmail || '',
  getSupportPhone: _state => _state.config?.supportPhone || '',
  getSupportChatHours: _state => _state.config?.supportChatHours || '',
  getSupportChatEnabled: _state => _state.config?.supportChatEnabled || false,
};

const actions = {
  setKanbanEnabled({ commit }, isEnabled) {
    commit(types.SET_KANBAN_ENABLED, isEnabled);
  },

  async fetchKanbanItems({ commit }) {
    console.log('[STORE-DEBUG] fetchKanbanItems iniciado');
    commit('SET_LOADING', true);
    try {
      const currentFunnel = this.getters['funnel/getSelectedFunnel'];
      if (!currentFunnel?.id) {
        throw new Error('Nenhum funil selecionado');
      }

      console.log(
        '[STORE-DEBUG] Buscando itens para o funil:',
        currentFunnel.id
      );
      const response = await KanbanAPI.getItems(currentFunnel.id);
      console.log(
        '[STORE-DEBUG] API getItems respondeu com',
        response.data.length,
        'itens'
      );

      commit('SET_KANBAN_ITEMS', response.data);
      console.log(
        '[STORE-DEBUG] Store atualizado com novos itens:',
        state.items.length
      );
      console.log(
        '[STORE-DEBUG] IDs dos novos itens:',
        state.items.map(i => i.id)
      );
      return response.data;
    } catch (error) {
      console.error('[STORE-DEBUG] Erro em fetchKanbanItems:', error);
      commit('SET_ERROR', error.message);
      throw error;
    } finally {
      commit('SET_LOADING', false);
    }
  },

  async createKanbanItem({ commit }, payload) {
    commit('SET_LOADING', true);
    try {
      const response = await KanbanAPI.createItem(payload);
      commit('ADD_KANBAN_ITEM', response.data);
      return response.data;
    } catch (error) {
      commit('SET_ERROR', error.message);
      throw error;
    } finally {
      commit('SET_LOADING', false);
    }
  },

  async moveItemToStage({ commit }, { itemId, columnId }) {
    console.log(
      '[MOVE-STORE-DEBUG] moveItemToStage iniciado - itemId:',
      itemId,
      'columnId:',
      columnId
    );

    // Garantir que itemId seja número
    const numericItemId = parseInt(itemId, 10);

    // Obter o item original para possível reversão
    const originalItem = state.items.find(i => i.id === numericItemId);
    console.log(
      '[MOVE-STORE-DEBUG] Item encontrado?',
      !!originalItem,
      'ID numérico:',
      numericItemId
    );
    console.log(
      '[MOVE-STORE-DEBUG] IDs no store:',
      state.items.map(i => i.id)
    );

    if (originalItem) {
      console.log(
        '[MOVE-STORE-DEBUG] Item antes da atualização:',
        originalItem.funnel_stage
      );
      // Modificar o item no store antes da API (igual à exclusão)
      commit('UPDATE_ITEM_STAGE', { itemId: numericItemId, columnId });
      console.log(
        '[MOVE-STORE-DEBUG] Após commit, valor do item atualizado:',
        state.items.find(i => i.id === numericItemId)?.funnel_stage
      );
    }

    try {
      // Chamar a API
      const response = await KanbanAPI.moveToStage(numericItemId, columnId);
      console.log('[MOVE-STORE-DEBUG] Resposta da API:', response);
      return true;
    } catch (error) {
      console.error('[MOVE-STORE-DEBUG] Erro na API:', error);
      // Em caso de erro, reverter para o estado original
      if (originalItem) {
        commit('UPDATE_ITEM_STAGE', {
          itemId: numericItemId,
          columnId: originalItem.funnel_stage,
        });
      }
      commit('SET_ERROR', error.message);
      throw error;
    }
  },

  async deleteKanbanItem({ commit }, itemId) {
    const originalItem = state.items.find(i => i.id === itemId);
    commit('REMOVE_KANBAN_ITEM', itemId);

    try {
      await KanbanAPI.deleteItem(itemId);
      return true;
    } catch (error) {
      if (originalItem) {
        commit('ADD_KANBAN_ITEM', originalItem);
      }
      commit('SET_ERROR', error.message);
      throw error;
    }
  },

  async updateItemStructure({ commit }, { itemId, structure }) {
    commit('SET_LOADING', true);
    try {
      const response = await KanbanAPI.updateItemStructure(itemId, {
        item: { item_structure: structure },
      });
      commit('UPDATE_ITEM_STRUCTURE', {
        itemId,
        structure: response.data.item_structure,
      });
      return response.data;
    } catch (error) {
      commit('SET_ERROR', error.message);
      throw error;
    } finally {
      commit('SET_LOADING', false);
    }
  },

  async updateItemDetails({ commit }, { itemId, details }) {
    commit('UPDATE_ITEM_DETAILS', { itemId, details });

    try {
      const response = await KanbanAPI.updateItemDetails(itemId, {
        item: { item_details: details },
      });
      return response.data;
    } catch (error) {
      commit('SET_ERROR', error.message);
      throw error;
    }
  },

  async fetchKanbanConfig({ commit }) {
    try {
      const response = await KanbanAPI.fetchConfig();

      const config = {
        title:
          window.globalConfig.KANBAN_TITLE ||
          response.data.KANBAN_TITLE ||
          'Kanban',
        defaultView: response.data.KANBAN_DEFAULT_VIEW || 'kanban',
        webhookUrl: response.data.KANBAN_WEBHOOK_URL || '',
        webhookSecret: response.data.KANBAN_WEBHOOK_SECRET || '',
        autoAssignment: response.data.KANBAN_AUTO_ASSIGNMENT === 'true',
        notificationsEnabled:
          response.data.KANBAN_NOTIFICATION_ENABLED === 'true',
        supportEmail: response.data.KANBAN_SUPPORT_EMAIL || '',
        supportPhone: response.data.KANBAN_SUPPORT_PHONE || '',
        supportChatHours: response.data.KANBAN_SUPPORT_CHAT_HOURS || '',
        supportChatEnabled:
          response.data.KANBAN_SUPPORT_CHAT_ENABLED === 'true',
      };

      commit('SET_KANBAN_CONFIG', config);
      return config;
    } catch (error) {
      console.warn('Erro ao carregar configurações do Kanban:', error);
      const defaultConfig = {
        title: window.globalConfig.KANBAN_TITLE || 'Kanban',
        defaultView: 'kanban',
        webhookUrl: '',
        webhookSecret: '',
        autoAssignment: false,
        notificationsEnabled: false,
        supportEmail: '',
        supportPhone: '',
        supportChatHours: '',
        supportChatEnabled: false,
      };
      commit('SET_KANBAN_CONFIG', defaultConfig);
      return defaultConfig;
    }
  },

  updateLocalItems({ commit }, items) {
    commit('SET_KANBAN_ITEMS', items);
  },

  async itemUpdated({ commit, dispatch }) {
    console.log('[STORE-DEBUG] itemUpdated foi chamado');
    commit('SET_LAST_UPDATED');
    console.log(
      '[STORE-DEBUG] Antes de fetchKanbanItems, itens atuais:',
      state.items.length
    );

    try {
      await dispatch('fetchKanbanItems');
      console.log(
        '[STORE-DEBUG] Após fetchKanbanItems, novos itens:',
        state.items.length
      );
      console.log(
        '[STORE-DEBUG] IDs dos itens atualizados:',
        state.items.map(i => i.id)
      );
      return true;
    } catch (error) {
      console.error('[STORE-DEBUG] Erro em itemUpdated:', error);
      return false;
    }
  },
};

const mutations = {
  [types.SET_KANBAN_ENABLED](_state, isEnabled) {
    _state.isEnabled = isEnabled;
  },
  SET_LOADING(_state, loading) {
    _state.loading = loading;
  },
  SET_ERROR(_state, error) {
    _state.error = error;
  },
  SET_KANBAN_ITEMS(_state, items) {
    _state.items = items;
  },
  ADD_KANBAN_ITEM(_state, item) {
    _state.items.push(item);
  },
  REMOVE_KANBAN_ITEM(_state, itemId) {
    _state.items = _state.items.filter(item => item.id !== itemId);
  },
  UPDATE_ITEM_STAGE(_state, { itemId, columnId }) {
    console.log(
      '[MUTATION-DEBUG] UPDATE_ITEM_STAGE chamada - itemId:',
      itemId,
      'columnId:',
      columnId
    );

    // Garantir que o itemId seja um número
    const numericItemId = parseInt(itemId, 10);
    console.log(
      '[MUTATION-DEBUG] Tipo do itemId:',
      typeof itemId,
      'Valor numérico:',
      numericItemId
    );

    // Buscar o item usando o ID numérico
    const item = _state.items.find(i => i.id === numericItemId);
    console.log(
      '[MUTATION-DEBUG] Item encontrado?',
      !!item,
      'IDs no store:',
      _state.items.map(i => i.id)
    );

    // Atualizar o item se encontrado
    if (item) {
      console.log(
        '[MUTATION-DEBUG] Atualizando item:',
        item.id,
        'de',
        item.funnel_stage,
        'para',
        columnId
      );
      item.funnel_stage = columnId;
      console.log('[MUTATION-DEBUG] Após atualização:', item.funnel_stage);
    } else {
      console.log('[MUTATION-DEBUG] Item não encontrado! ID:', numericItemId);
    }
  },
  UPDATE_ITEM_STRUCTURE(_state, { itemId, structure }) {
    const item = _state.items.find(i => i.id === itemId);
    if (item) {
      item.item_structure = structure;
    }
  },
  UPDATE_ITEM_DETAILS(_state, { itemId, details }) {
    const item = _state.items.find(i => i.id === itemId);
    if (item) {
      item.item_details = details;
    }
  },
  SET_KANBAN_CONFIG(_state, config) {
    _state.config = config;
  },
  SET_LAST_UPDATED(_state) {
    _state.lastUpdated = new Date().getTime();
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
