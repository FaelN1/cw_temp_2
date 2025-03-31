/* global axios */
import ApiClient from './ApiClient';
import store from '../store';
import webhookService from '../services/kanban/webhookService';

class KanbanAPI extends ApiClient {
  constructor() {
    super('kanban_items', { accountScoped: true });
  }

  get accountId() {
    return store.state.auth.currentUser.account_id;
  }

  async getItems(funnelId) {
    const params = {
      funnel_id: funnelId || store.getters['funnel/getSelectedFunnel']?.id,
    };

    return this.get('', { params });
  }

  async getItem(itemId) {
    const response = await axios.get(`${this.url}/${itemId}`);
    return response;
  }

  async createItem(data) {
    try {
      const response = await axios.post(this.url, {
        kanban_item: data,
      });
      await webhookService.notifyItemCreated(response.data);
      return response;
    } catch (error) {
      console.error('Erro ao criar item:', error);
      throw error;
    }
  }

  async updateItem(itemId, data) {
    try {
      const { data: currentItem } = await this.getItem(itemId);
      const response = await axios.put(`${this.url}/${itemId}`, {
        kanban_item: data,
      });

      const changes = {};
      Object.keys(data).forEach(key => {
        if (JSON.stringify(currentItem[key]) !== JSON.stringify(data[key])) {
          changes[key] = {
            from: currentItem[key],
            to: data[key],
          };
        }
      });

      if (Object.keys(changes).length > 0) {
        await webhookService.notifyItemUpdated(response.data, changes);
      }

      return response;
    } catch (error) {
      console.error('Erro ao atualizar item:', error);
      throw error;
    }
  }

  async deleteItem(itemId) {
    try {
      const { data: currentItem } = await this.getItem(itemId);
      const response = await axios.delete(`${this.url}/${itemId}`);

      await webhookService.notifyItemDeleted(currentItem);
      return response;
    } catch (error) {
      console.error('Erro ao deletar item:', error);
      throw error;
    }
  }

  async moveToStage(itemId, funnelStage) {
    try {
      const { data: currentItem } = await this.getItem(itemId);
      const fromStage = currentItem.funnel_stage;

      const response = await axios.post(`${this.url}/${itemId}/move_to_stage`, {
        funnel_stage: funnelStage,
        stage_entered_at: new Date().toISOString(),
      });

      const { data: updatedItem } = await this.getItem(itemId);

      await webhookService.notifyStageChange(
        updatedItem,
        fromStage,
        funnelStage
      );

      return updatedItem;
    } catch (error) {
      console.error('Erro ao mover item:', error);
      throw error;
    }
  }

  async reorderItems(positions) {
    try {
      const currentItems = await Promise.all(
        positions.map(pos => this.getItem(pos.id))
      );

      const response = await axios.post(`${this.url}/reorder`, {
        positions,
      });

      const changes = positions.map(pos => ({
        item_id: pos.id,
        old_position: currentItems.find(item => item.data.id === pos.id)?.data
          .position,
        new_position: pos.position,
      }));

      await webhookService.notifyItemReordered(response.data, changes);
      return response;
    } catch (error) {
      console.error('Erro ao reordenar itens:', error);
      throw error;
    }
  }

  async startTimer(itemId) {
    try {
      const response = await this.updateItem(itemId, {
        timer_started_at: new Date().toISOString(),
      });

      await webhookService.notifyTimerStarted(response.data);
      return response;
    } catch (error) {
      console.error('Erro ao iniciar timer:', error);
      throw error;
    }
  }

  async stopTimer(itemId) {
    try {
      const response = await this.updateItem(itemId, {
        timer_started_at: null,
      });

      const duration = response.data.timer_duration;
      await webhookService.notifyTimerStopped(response.data, duration);
      return response;
    } catch (error) {
      console.error('Erro ao parar timer:', error);
      throw error;
    }
  }

  async getItemByConversationId(conversationId) {
    const response = await this.get('', {
      params: {
        'item_details.conversation_id': conversationId,
      },
    });
    return response;
  }

  // Automations
  async getAutomations() {
    try {
      const response = await axios.get(
        `/api/v1/accounts/${this.accountId}/kanban/automations`
      );
      return response;
    } catch (error) {
      console.error('Erro ao buscar automações:', error);
      return { data: [] };
    }
  }

  async getAutomation(id) {
    try {
      const response = await axios.get(
        `/api/v1/accounts/${this.accountId}/kanban/automations/${id}`
      );
      return response;
    } catch (error) {
      throw error;
    }
  }

  async createAutomation(data) {
    try {
      const response = await axios.post(
        `/api/v1/accounts/${this.accountId}/kanban/automations`,
        { kanban_automation: data }
      );
      return response;
    } catch (error) {
      throw error;
    }
  }

  async updateAutomation(id, data) {
    try {
      const response = await axios.patch(
        `/api/v1/accounts/${this.accountId}/kanban/automations/${id}`,
        { kanban_automation: data }
      );
      return response;
    } catch (error) {
      throw error;
    }
  }

  async deleteAutomation(id) {
    try {
      const response = await axios.delete(
        `/api/v1/accounts/${this.accountId}/kanban/automations/${id}`
      );
      return response;
    } catch (error) {
      throw error;
    }
  }

  async getBatchData(funnelId) {
    const response = await axios.get(`${this.url}/batch`, {
      params: {
        funnel_id: funnelId,
      },
    });

    return response.data;
  }
}

export default new KanbanAPI();
