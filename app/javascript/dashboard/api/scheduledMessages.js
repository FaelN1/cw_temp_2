import ApiClient from './ApiClient';

class ScheduledMessagesAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  schedule(data) {
    return axios.post(`${this.url}/${data.conversationId}/schedule_message`, {
      inbox_id: data.inboxId,
      content: data.message,
      scheduled_at: data.scheduledAt,
      title: data.title
    });
  }

  get({ conversationId, page = 1 } = {}) {
    return axios.get(`${this.url}/${conversationId}/scheduled_messages`, {
      params: { page }
    });
  }

  update(conversationId, id, data) {
    return axios.patch(`${this.url}/${conversationId}/scheduled_messages/${id}`, {
      content: data.message,
      scheduled_at: data.scheduledAt,
      title: data.title
    });
  }

  delete(conversationId, id) {
    return axios.delete(`${this.url}/${conversationId}/scheduled_messages/${id}`);
  }

  getCount(conversationId) {
    return axios.get(`${this.url}/${conversationId}/scheduled_messages/count`, {
      params: { status: 'pending' }
    });
  }
}

export default new ScheduledMessagesAPI(); 