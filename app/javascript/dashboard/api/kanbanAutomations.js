/* global axios */
import ApiClient from './ApiClient';

class KanbanAutomationsAPI extends ApiClient {
  constructor() {
    // Usar 'kanban/automations' como endpoint base e habilitar account scoped
    super('kanban/automations', { accountScoped: true });
  }

  // Métodos CRUD básicos - o account_id será inserido automaticamente pela classe pai

  async get() {
    try {
      const response = await axios.get(this.url);
      return response;
    } catch (error) {
      console.error('Erro ao buscar automações:', error);
      return { data: [] };
    }
  }

  async show(id) {
    try {
      const response = await axios.get(`${this.url}/${id}`);
      return response;
    } catch (error) {
      console.error(`Erro ao buscar automação #${id}:`, error);
      throw error;
    }
  }

  async create(data) {
    try {
      const response = await axios.post(this.url, { kanban_automation: data });
      return response;
    } catch (error) {
      console.error('Erro ao criar automação:', error);
      throw error;
    }
  }

  async update(id, data) {
    try {
      const response = await axios.patch(`${this.url}/${id}`, {
        kanban_automation: data,
      });
      return response;
    } catch (error) {
      console.error(`Erro ao atualizar automação #${id}:`, error);
      throw error;
    }
  }

  async destroy(id) {
    try {
      const response = await axios.delete(`${this.url}/${id}`);
      return response;
    } catch (error) {
      console.error(`Erro ao excluir automação #${id}:`, error);
      throw error;
    }
  }
}

export default new KanbanAutomationsAPI();
