import ConversationApi from '../../../../api/inbox/conversation';

export default {
  async scheduleMessage(_, { conversationId, inboxId, content, scheduledAt }) {
    try {
      const response = await ConversationApi.scheduleMessage({
        conversation_id: conversationId,
        inbox_id: inboxId,
        content,
        scheduled_at: scheduledAt,
      });
      return response.data;
    } catch (error) {
      throw new Error(error);
    }
  },

  async getScheduledMessagesCount(_, conversationId) {
    try {
      const response = await ConversationApi.getScheduledMessagesCount(conversationId);
      return response.data;
    } catch (error) {
      throw new Error(error);
    }
  },
}; 