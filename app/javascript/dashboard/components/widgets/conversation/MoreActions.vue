<!-- eslint-disable no-restricted-syntax -->
<!-- eslint-disable no-await-in-loop -->
<!-- eslint-disable no-console -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

export default {
  components: {
    EmailTranscriptModal,
    ResolveAction,
  },
  data() {
    return {
      showEmailActionsModal: false,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      callInfo: 'webphone/getCallInfo',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      accountId: 'getCurrentAccountId',
    }),
    currentContact() {
      return this.$store.getters['contacts/getContact'](
        this.currentChat.meta.sender.id
      );
    },
    isWavoipFeatureEnabled() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.WAVOIP
      );
    },
  },
  mounted() {
    // Verificar se this.$emitter existe antes de usar
    if (this.$emitter) {
      this.$emitter.on(CMD_MUTE_CONVERSATION, this.mute);
      this.$emitter.on(CMD_UNMUTE_CONVERSATION, this.unmute);
      this.$emitter.on(CMD_SEND_TRANSCRIPT, this.toggleEmailActionsModal);
    } else {
      console.warn(
        '$emitter não está disponível. Alguns recursos podem não funcionar corretamente.'
      );
    }

    // Inicializar o Wavoip se necessário
    if (this.isWavoipFeatureEnabled && !this.callInfo.id) {
      console.log(
        'Verificando se é necessário inicializar o Wavoip no MoreActions mounted'
      );
      // Este é um bom lugar para forçar a inicialização do componente Webphone, se necessário
    }
  },
  unmounted() {
    // Verificar se this.$emitter existe antes de usar
    if (this.$emitter) {
      this.$emitter.off(CMD_MUTE_CONVERSATION, this.mute);
      this.$emitter.off(CMD_UNMUTE_CONVERSATION, this.unmute);
      this.$emitter.off(CMD_SEND_TRANSCRIPT, this.toggleEmailActionsModal);
    }
  },
  methods: {
    async startCall() {
      console.log('startCall');
      console.log('CallInfo', this.callInfo);

      try {
        if (this.callInfo && this.callInfo.id) {
          console.log('Call already in progress');
          useAlert(this.$t('WEBPHONE.CALL_ALREADY_IN_PROGRESS'));
          return;
        }

        if (!this.currentContact) {
          console.log('No contact found');
          useAlert(this.$t('WEBPHONE.CONTACT_NOT_FOUND'));
          return;
        }

        console.log('currentContact', this.currentContact);
        console.log(
          'currentContact.phone_number',
          this.currentContact.phone_number
        );

        if (!this.currentContact.phone_number) {
          console.log('Número de telefone não encontrado no contato');
          useAlert(this.$t('WEBPHONE.CONTACT_PHONE_NOT_FOUND'));
          return;
        }

        // Verifica se o Wavoip já está inicializado
        const wavoipInstances = this.$store.state.webphone.wavoip;
        console.log('Instâncias Wavoip disponíveis:', wavoipInstances);

        if (!Object.keys(wavoipInstances).length) {
          console.log(
            'Nenhuma instância Wavoip disponível, tentando inicializar...'
          );
          // Se não há instâncias, tenta inicializar a partir dos inboxes disponíveis
          const inboxes = this.$store.getters['inboxes/getInboxes'];
          if (inboxes && inboxes.length) {
            for (const inbox of inboxes) {
              if (inbox.external_token) {
                console.log('Inicializando Wavoip para:', inbox.name);
                await this.$store.dispatch('webphone/startWavoip', {
                  inboxName: inbox.name,
                  token: inbox.external_token,
                });
                break; // Inicializa apenas o primeiro disponível por enquanto
              }
            }
          }
        }

        await this.$store.dispatch('webphone/outcomingCall', {
          contact_name: this.currentContact.name,
          profile_picture: this.currentContact.thumbnail,
          phone: this.currentContact.phone_number,
          chat_id: this.currentChat.id,
        });
      } catch (error) {
        console.log('Erro ao fazer chamada:', error);
        if (error.message === 'Número não existe') {
          useAlert(this.$t('WEBPHONE.CONTACT_INVALID'));
        } else if (
          error.message === 'Linha ocupada, tente mais tarde ou faça um upgrade'
        ) {
          useAlert(this.$t('WEBPHONE.ALL_INSTANCE_BUSY'));
        } else if (error.message === 'Limite de ligações atingido') {
          useAlert(this.$t('WEBPHONE.CALL_LIMIT'));
        } else if (error.message === 'NO_AVAILABLE_INSTANCES') {
          useAlert(this.$t('WEBPHONE.NO_AVAILABLE_INSTANCES'));
        } else {
          useAlert(this.$t('WEBPHONE.ERROR_TO_MADE_CALL'));
        }
      }
    },
    mute() {
      this.$store.dispatch('muteConversation', this.currentChat.id);
      useAlert(this.$t('CONTACT_PANEL.MUTED_SUCCESS'));
    },
    unmute() {
      this.$store.dispatch('unmuteConversation', this.currentChat.id);
      useAlert(this.$t('CONTACT_PANEL.UNMUTED_SUCCESS'));
    },
    toggleEmailActionsModal() {
      this.showEmailActionsModal = !this.showEmailActionsModal;
    },
  },
};
</script>

<template>
  <div class="relative flex items-center gap-2 actions--container">
    <woot-button
      v-if="isWavoipFeatureEnabled"
      v-tooltip="$t('WEBPHONE.CALL')"
      variant="clear"
      color-scheme="secondary"
      icon="call"
      :disabled="callInfo && callInfo.id"
      @click="startCall"
    />
    <woot-button
      v-if="!currentChat.muted"
      v-tooltip="$t('CONTACT_PANEL.MUTE_CONTACT')"
      variant="clear"
      color-scheme="secondary"
      icon="speaker-mute"
      @click="mute"
    />
    <woot-button
      v-else
      v-tooltip.left="$t('CONTACT_PANEL.UNMUTE_CONTACT')"
      variant="clear"
      color-scheme="secondary"
      icon="speaker-1"
      @click="unmute"
    />
    <woot-button
      v-tooltip="$t('CONTACT_PANEL.SEND_TRANSCRIPT')"
      variant="clear"
      color-scheme="secondary"
      icon="share"
      @click="toggleEmailActionsModal"
    />
    <ResolveAction
      :conversation-id="currentChat.id"
      :status="currentChat.status"
    />
    <EmailTranscriptModal
      v-if="showEmailActionsModal"
      :show="showEmailActionsModal"
      :current-chat="currentChat"
      @cancel="toggleEmailActionsModal"
    />
  </div>
</template>

<style scoped lang="scss">
.more--button {
  @apply items-center flex ml-2 rtl:ml-0 rtl:mr-2;
}

.dropdown-pane {
  @apply -right-2 top-12;
}

.icon {
  @apply mr-1 rtl:mr-0 rtl:ml-1 min-w-[1rem];
}
</style>
