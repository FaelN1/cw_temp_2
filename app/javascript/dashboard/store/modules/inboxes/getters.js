import { INBOX_TYPES } from '../../../helper/inbox';

export const getters = {
  getApiAndWhatsAppInboxes: _state => state => {
    return state.records.filter(
      inbox =>
        inbox.channel_type === INBOX_TYPES.API ||
        inbox.channel_type === INBOX_TYPES.WHATSAPP
    );
  },
};
