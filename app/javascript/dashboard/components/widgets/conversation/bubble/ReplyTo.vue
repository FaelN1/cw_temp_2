<script>
import MessagePreview from 'dashboard/components/widgets/conversation/MessagePreview.vue';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

export default {
  name: 'ReplyTo',
  components: {
    MessagePreview,
  },
  props: {
    message: {
      type: Object,
      required: true,
    },
    messageType: {
      type: Number,
      required: true,
    },
    parentHasAttachments: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return { MESSAGE_TYPE };
  },
  methods: {
    scrollToMessage() {
      emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
        messageId: this.message.id,
      });
      const targetMessage = document.getElementById(
        `message${this.message.id}`
      );
      if (targetMessage) {
        targetMessage.classList.add('has-bg');
        const HIGHLIGHT_TIMER = 2000;
        setTimeout(() => {
          targetMessage.classList.remove('has-bg');
        }, HIGHLIGHT_TIMER);
      }
    },
  },
};
</script>

<template>
  <div
    class="px-8 py-1.5 rounded-sm min-w-[10rem] mb-2"
    :class="{
      'bg-slate-50 dark:bg-slate-600 dark:text-slate-50':
        messageType === MESSAGE_TYPE.INCOMING,
      'bg-woot-600 text-woot-50': messageType === MESSAGE_TYPE.OUTGOING,
      'w-52': !parentHasAttachments,
    }"
    @click="scrollToMessage"
  >
    <MessagePreview
      class="cursor-pointer"
      :message="message"
      :show-message-type="false"
      :default-empty-message="$t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND')"
      :short="false"
    />
  </div>
</template>
