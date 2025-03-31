import axios from 'axios';

class WebhookService {
  constructor() {
    this.webhookUrl = localStorage.getItem('kanban_webhook_url') || '';
    this.isEnabled = localStorage.getItem('kanban_webhook_enabled') === 'true';
  }

  setWebhookConfig({ url, enabled }) {
    this.webhookUrl = url;
    this.isEnabled = enabled;
    localStorage.setItem('kanban_webhook_url', url);
    localStorage.setItem('kanban_webhook_enabled', enabled);
  }

  formatItemData(itemData) {
    if (!itemData) {
      console.warn('WebhookService - itemData é null ou undefined');
      return null;
    }

    // Retorna o objeto completo sem formatação adicional
    // para manter todos os dados originais do item
    return {
      id: itemData.id,
      account_id: itemData.account_id,
      conversation_display_id: itemData.conversation_display_id,
      funnel_id: itemData.funnel_id,
      funnel_stage: itemData.funnel_stage,
      stage_entered_at: itemData.stage_entered_at,
      position: itemData.position,
      custom_attributes: itemData.custom_attributes || {},
      item_details: {
        ...itemData.item_details,
        notes: itemData.item_details?.notes || [],
        checklist: itemData.item_details?.checklist || [],
        title: itemData.item_details?.title,
        value: itemData.item_details?.value,
        agent_id: itemData.item_details?.agent_id,
        priority: itemData.item_details?.priority,
        description: itemData.item_details?.description,
        conversation_id: itemData.item_details?.conversation_id,
      },
      timer_started_at: itemData.timer_started_at,
      timer_duration: itemData.timer_duration,
      created_at: itemData.created_at,
      updated_at: itemData.updated_at,
    };
  }

  async notifyStageChange(itemData, fromStage, toStage) {
    if (!this.isEnabled || !this.webhookUrl) {
      console.log('WebhookService - Webhook desativado ou sem URL configurada');
      return;
    }

    try {
      const formattedItem = this.formatItemData(itemData);

      const payload = {
        event: 'kanban.item.stage_changed',
        data: {
          item: formattedItem,
          from_stage: fromStage,
          to_stage: toStage,
          timestamp: new Date().toISOString(),
        },
      };

      await axios.post(this.webhookUrl, payload);
    } catch (error) {
      console.error('Erro ao notificar webhook:', error);
      throw new Error('Falha ao notificar webhook');
    }
  }

  async notifyItemUpdated(itemData, changes = {}) {
    if (!this.isEnabled || !this.webhookUrl) {
      console.log('WebhookService - Webhook desativado ou sem URL configurada');
      return;
    }

    try {
      const formattedItem = this.formatItemData(itemData);

      const payload = {
        event: 'kanban.item.updated',
        data: {
          item: formattedItem,
          changes: changes,
          timestamp: new Date().toISOString(),
        },
      };

      await axios.post(this.webhookUrl, payload);
    } catch (error) {
      console.error('Erro ao notificar webhook de atualização:', error);
      throw new Error('Falha ao notificar webhook de atualização');
    }
  }

  async notifyItemCreated(itemData) {
    if (!this.isEnabled || !this.webhookUrl) {
      console.log('WebhookService - Webhook desativado ou sem URL configurada');
      return;
    }

    try {
      const formattedItem = this.formatItemData(itemData);

      const payload = {
        event: 'kanban.item.created',
        data: {
          item: formattedItem,
          timestamp: new Date().toISOString(),
        },
      };

      await axios.post(this.webhookUrl, payload);
    } catch (error) {
      console.error('Erro ao notificar webhook de criação:', error);
      throw new Error('Falha ao notificar webhook de criação');
    }
  }

  async notifyItemDeleted(itemData) {
    if (!this.isEnabled || !this.webhookUrl) {
      console.log('WebhookService - Webhook desativado ou sem URL configurada');
      return;
    }

    try {
      const formattedItem = this.formatItemData(itemData);

      const payload = {
        event: 'kanban.item.deleted',
        data: {
          item: formattedItem,
          timestamp: new Date().toISOString(),
        },
      };

      await axios.post(this.webhookUrl, payload);
    } catch (error) {
      console.error('Erro ao notificar webhook de exclusão:', error);
      throw new Error('Falha ao notificar webhook de exclusão');
    }
  }

  async notifyTimerStarted(itemData) {
    if (!this.isEnabled || !this.webhookUrl) {
      console.log('WebhookService - Webhook desativado ou sem URL configurada');
      return;
    }

    try {
      const formattedItem = this.formatItemData(itemData);

      const payload = {
        event: 'kanban.item.timer_started',
        data: {
          item: formattedItem,
          timestamp: new Date().toISOString(),
        },
      };

      await axios.post(this.webhookUrl, payload);
    } catch (error) {
      console.error('Erro ao notificar webhook de início do timer:', error);
      throw new Error('Falha ao notificar webhook de início do timer');
    }
  }

  async notifyTimerStopped(itemData, duration) {
    if (!this.isEnabled || !this.webhookUrl) {
      console.log('WebhookService - Webhook desativado ou sem URL configurada');
      return;
    }

    try {
      const formattedItem = this.formatItemData(itemData);

      const payload = {
        event: 'kanban.item.timer_stopped',
        data: {
          item: formattedItem,
          duration: duration,
          timestamp: new Date().toISOString(),
        },
      };

      await axios.post(this.webhookUrl, payload);
    } catch (error) {
      console.error('Erro ao notificar webhook de parada do timer:', error);
      throw new Error('Falha ao notificar webhook de parada do timer');
    }
  }

  async notifyItemReordered(items, changes) {
    if (!this.isEnabled || !this.webhookUrl) {
      console.log('WebhookService - Webhook desativado ou sem URL configurada');
      return;
    }

    try {
      const formattedItems = items.map(item => this.formatItemData(item));

      const payload = {
        event: 'kanban.items.reordered',
        data: {
          items: formattedItems,
          changes: changes,
          timestamp: new Date().toISOString(),
        },
      };

      await axios.post(this.webhookUrl, payload);
    } catch (error) {
      console.error('Erro ao notificar webhook de reordenação:', error);
      throw new Error('Falha ao notificar webhook de reordenação');
    }
  }
}

export default new WebhookService();
