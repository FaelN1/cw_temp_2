import mutationTypes from '../mutation-types';

const state = {
  isEnabled: false,
};

const getters = {
  isScheduleMessagesEnabled: $state => {
    console.log('[scheduleMessages] getter isEnabled:', $state.isEnabled);
    return $state.isEnabled;
  },
};

const actions = {
  setScheduleMessagesEnabled({ commit }, enabled) {
    console.log('[scheduleMessages] action setEnabled:', enabled);
    commit('SET_SCHEDULE_MESSAGES_ENABLED', enabled);
  },
};

const mutations = {
  SET_SCHEDULE_MESSAGES_ENABLED($state, enabled) {
    console.log('[scheduleMessages] mutation setEnabled:', enabled);
    $state.isEnabled = enabled;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
}; 