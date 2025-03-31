import types from '../mutation-types';
import FunnelAPI from '../../api/funnel';

const STORAGE_KEY = 'selectedFunnelId';

const state = {
  records: [],
  selectedFunnel: null,
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
  },
};

const getters = {
  getFunnels: $state => $state.records,
  getSelectedFunnel: $state => $state.selectedFunnel,
  getUIFlags: $state => $state.uiFlags,
  getFunnelById: state => id => {
    return state.records.find(funnel => String(funnel.id) === String(id));
  },
};

const actions = {
  async fetch({ commit, dispatch }) {
    commit(types.SET_FUNNEL_UI_FLAG, { isFetching: true });
    try {
      const { data } = await FunnelAPI.get();
      const formattedData = data.map(funnel => ({
        ...funnel,
        id: String(funnel.id),
        stages: Object.entries(funnel.stages || {}).reduce(
          (acc, [key, stage]) => ({
            ...acc,
            [String(key)]: {
              ...stage,
              position: parseInt(stage.position, 10) || 0,
            },
          }),
          {}
        ),
      }));
      commit(types.SET_FUNNELS, formattedData);

      // Recupera o ID do funil salvo no localStorage
      const savedFunnelId = localStorage.getItem(STORAGE_KEY);

      if (savedFunnelId) {
        // Procura o funil salvo na lista de funis
        const savedFunnel = formattedData.find(
          funnel => funnel.id === savedFunnelId
        );
        if (savedFunnel) {
          await dispatch('setSelectedFunnel', savedFunnel);
          return formattedData;
        }
      }

      // Se não houver funil salvo ou ele não existir mais, seleciona o primeiro
      if (!state.selectedFunnel && formattedData.length > 0) {
        await dispatch('setSelectedFunnel', formattedData[0]);
      }

      return formattedData;
    } catch (error) {
      console.error('Erro ao buscar funis:', error);
      throw error;
    } finally {
      commit(types.SET_FUNNEL_UI_FLAG, { isFetching: false });
    }
  },

  async setSelectedFunnel({ commit }, funnel) {
    if (!funnel?.id) {
      console.error('Tentativa de selecionar funil inválido:', funnel);
      return;
    }

    try {
      commit(types.SET_FUNNEL_UI_FLAG, { isUpdating: true });

      // Salva o ID do funil no localStorage
      localStorage.setItem(STORAGE_KEY, String(funnel.id));

      commit(types.SET_SELECTED_FUNNEL, funnel);
    } finally {
      commit(types.SET_FUNNEL_UI_FLAG, { isUpdating: false });
    }
  },
};

const mutations = {
  [types.SET_FUNNELS]($state, data) {
    $state.records = data;
  },
  [types.SET_SELECTED_FUNNEL]($state, funnel) {
    $state.selectedFunnel = funnel;
  },
  [types.SET_FUNNEL_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
