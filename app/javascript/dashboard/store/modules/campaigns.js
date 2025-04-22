/* eslint-disable no-console */
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import CampaignsAPI from '../../api/campaigns';
import AnalyticsHelper from '../../helper/AnalyticsHelper';
import { CAMPAIGNS_EVENTS } from '../../helper/AnalyticsHelper/events';
import { CAMPAIGN_CHANNEL_TYPES } from 'shared/constants/campaign';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getCampaigns:
    _state =>
    (campaignType, channelType = null) => {
      // Se campaignType for null, não aplica filtro de tipo
      let filteredRecords = campaignType
        ? _state.records.filter(record => record.campaign_type === campaignType)
        : _state.records;

      // Se um tipo de canal for especificado, filtra ainda mais as campanhas
      if (channelType) {
        filteredRecords = filteredRecords.filter(record => {
          // Para WhatsApp ou API, verifica os tipos de canal correspondentes
          if (
            channelType === CAMPAIGN_CHANNEL_TYPES.WHATSAPP ||
            channelType === CAMPAIGN_CHANNEL_TYPES.API
          ) {
            return (
              record.inbox?.channel_type === 'Channel::Whatsapp' ||
              record.inbox?.channel_type === 'Channel::Api'
            );
          }
          // Para SMS, verifica se o inbox NÃO é do tipo WhatsApp (é SMS ou Twilio SMS)
          if (channelType === CAMPAIGN_CHANNEL_TYPES.SMS) {
            return record.inbox?.channel_type !== 'Channel::Sms';
          }
          return true;
        });
      }

      return filteredRecords.sort((a1, a2) => a1.id - a2.id);
    },
  getWhatsAppCampaigns: _state => {
    return _state.records
      .filter(record => record.inbox?.channel_type === 'Channel::Whatsapp')
      .sort((a1, a2) => a1.id - a2.id);
  },
  getAllCampaigns: _state => {
    return _state.records;
  },
};

export const actions = {
  get: async function getCampaigns({ commit }) {
    commit(types.SET_CAMPAIGN_UI_FLAG, { isFetching: true });
    try {
      const response = await CampaignsAPI.get();
      commit(types.SET_CAMPAIGNS, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_CAMPAIGN_UI_FLAG, { isFetching: false });
    }
  },
  create: async function createCampaign({ commit }, campaignObj) {
    console.log('=== INICIANDO CRIAÇÃO DE CAMPANHA ===');
    console.log('Payload de entrada:', campaignObj);
    commit(types.SET_CAMPAIGN_UI_FLAG, { isCreating: true });
    try {
      console.log('Enviando requisição para a API...');
      const response = await CampaignsAPI.create(campaignObj);
      console.log('Resposta da API:', response);
      console.log('Dados da campanha criada:', response.data);
      commit(types.ADD_CAMPAIGN, response.data);
      console.log('=== CAMPANHA CRIADA COM SUCESSO ===');
      return response.data;
    } catch (error) {
      console.error('=== ERRO AO CRIAR CAMPANHA ===');
      console.error('Objeto do erro:', error);
      console.error('Detalhes da resposta:', error.response);
      console.error('Mensagem:', error.message);

      if (error.response && error.response.data) {
        console.error('Dados do erro:', error.response.data);
        console.error('Status do erro:', error.response.status);
      }

      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      }

      if (error.response?.data?.error) {
        throw new Error(error.response.data.error);
      }

      throw error;
    } finally {
      commit(types.SET_CAMPAIGN_UI_FLAG, { isCreating: false });
      console.log('=== FINALIZADO PROCESSAMENTO DE CAMPANHA ===');
    }
  },
  update: async ({ commit }, { id, ...updateObj }) => {
    commit(types.SET_CAMPAIGN_UI_FLAG, { isUpdating: true });
    try {
      const response = await CampaignsAPI.update(id, updateObj);
      AnalyticsHelper.track(CAMPAIGNS_EVENTS.UPDATE_CAMPAIGN);
      commit(types.EDIT_CAMPAIGN, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CAMPAIGN_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_CAMPAIGN_UI_FLAG, { isDeleting: true });
    try {
      await CampaignsAPI.delete(id);
      AnalyticsHelper.track(CAMPAIGNS_EVENTS.DELETE_CAMPAIGN);
      commit(types.DELETE_CAMPAIGN, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_CAMPAIGN_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_CAMPAIGN_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.ADD_CAMPAIGN]: MutationHelpers.create,
  [types.SET_CAMPAIGNS]: MutationHelpers.set,
  [types.EDIT_CAMPAIGN]: MutationHelpers.update,
  [types.DELETE_CAMPAIGN]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
