import ApiClient from '../ApiClient';

class WhatsAppTemplatesAPI extends ApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  getTemplates(inboxId) {
    return this.get(`${inboxId}/whatsapp_templates`);
  }
}

export default new WhatsAppTemplatesAPI();
