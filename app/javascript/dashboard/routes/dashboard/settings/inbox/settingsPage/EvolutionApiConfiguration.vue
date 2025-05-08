<!-- eslint-disable no-plusplus -->
<!-- eslint-disable vue/require-explicit-emits -->
<!-- eslint-disable vue/order-in-components -->
<!-- eslint-disable no-console -->
<script>
import SettingsSection from 'dashboard/components/SettingsSection.vue';
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';
import { actions } from '../../../../../store/modules/draftMessages';
import globalConfigMixin from 'shared/mixins/globalConfigMixin';
import axios from 'axios';

export default {
  components: {
    SettingsSection,
  },
  mixins: [actions, globalConfigMixin],
  data() {
    return {
      CHATWOOT_URL: window.location.origin,
      evoInstanceName: '',
      connected: false,
      serverStatus: true,
      img: false,
      section1_message: this.$t(
        'INBOX_MGMT.EVOLUTION_API_CONFIG.CONNECTWHATSAPP'
      ),
      loading: false,
      sec: 0,

      settings_rejectCall: false,
      settings_msgCall: '',
      settings_groupsIgnore: true,
      settings_alwaysOnline: false,
      settings_readMessages: false,
      settings_readStatus: false,
      settings_syncFullHistory: true,

      chatwootSignMsg: false,
      chatwootReopenConversation: true,
      chatwootConversationPending: false,
      chatwootImportContacts: true,
      chatwootImportMessages: true,
      chatwootMergeBrazilContacts: false,
      chatwootDaysLimitImportMessages: 30,
      chatwootNameInbox: '',
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      accountId: 'getCurrentAccountId',
      globalConfig: 'globalConfig/get',
    }),
  },
  async mounted() {
    this.proxify = `${this.CHATWOOT_URL}/api/v1/accounts/${this.accountId}/proxifier/evolution`;
    this.evoInstanceName = `${this.accountId}_${this.inbox.id}_${this.inbox.inbox_identifier}`;

    this.status();
  },
  methods: {
    async request(method, path, payload = {}) {
      const headers = {
        'Content-Type': 'application/json',
        api_access_token: this.currentUser.access_token,
        path: path,
      };
      try {
        const response = await axios({
          method,
          url: this.proxify,
          data: payload,
          headers,
        });
        return response;
      } catch (error) {
        console.error(error);
        throw error;
      }
    },

    async toogleSwitch(name, value) {
      this[name] = value;
      console.log(name, value);

      if (name.includes('chatwoot')) {
        this.loading = true;
        try {
          await this.setChatwoot();
        } catch (error) {
          console.error('Error al actualizar chatwoot settings', error);
        } finally {
          this.loading = false;
        }
      }
      if (name.includes('settings_')) {
        this.loading = true;
        try {
          await this.setSettings();
        } catch (error) {
          console.error('Error al actualizar settings', error);
        } finally {
          this.loading = false;
        }
      }
    },

    async feed() {
      this.loading = true;
      try {
        const evo_settings = await this.request(
          'get',
          `/settings/find/${this.evoInstanceName}`
        );
        console.log(evo_settings);
        const evo_chatwoot = await this.request(
          'get',
          `/chatwoot/find/${this.evoInstanceName}`
        );
        console.log(evo_chatwoot);

        // settings
        this.settings_rejectCall = evo_settings.data.rejectCall;
        this.settings_msgCall = evo_settings.data.msgCall;
        this.settings_groupsIgnore = evo_settings.data.groupsIgnore;
        this.settings_alwaysOnline = evo_settings.data.alwaysOnline;
        this.settings_readMessages = evo_settings.data.readMessages;
        this.settings_readStatus = evo_settings.data.readStatus;
        this.settings_syncFullHistory = evo_settings.data.syncFullHistory;
        // chatwoot
        if (evo_chatwoot.data.enabled === true) {
          this.chatwootSignMsg = evo_chatwoot.data.signMsg;
          this.chatwootReopenConversation =
            evo_chatwoot.data.reopenConversation;
          this.chatwootConversationPending =
            evo_chatwoot.data.conversationPending;
          this.chatwootImportContacts = evo_chatwoot.data.importContacts;
          this.chatwootImportMessages = evo_chatwoot.data.importMessages;
          this.chatwootMergeBrazilContacts =
            evo_chatwoot.data.mergeBrazilContacts;
          this.chatwootDaysLimitImportMessages =
            evo_chatwoot.data.daysLimitImportMessages;
          await this.setChatwootWebhook(evo_chatwoot.data.webhook_url);
        } else {
          await this.setChatwoot();
        }
      } catch (error) {
        console.error(error);
      } finally {
        this.loading = false;
      }
    },

    async status() {
      this.loading = true;
      try {
        const response = await this.request(
          'get',
          `/instance/connectionState/${this.evoInstanceName}`
        );
        console.log(response);

        if (response.data.instance.state === 'open') {
          this.connected = true;
          this.section1_message = this.$t(
            'INBOX_MGMT.EVOLUTION_API_CONFIG.ONLINE'
          );
          this.feed();
        } else {
          this.connected = false;
          this.section1_message = this.$t(
            'INBOX_MGMT.EVOLUTION_API_CONFIG.CONNECTWHATSAPP'
          );
        }
      } catch (error) {
        console.error(error);
        this.create();
      } finally {
        this.loading = false;
      }
    },

    countdown() {
      this.counting = true;
      this.sec = 20;
      this.section1_message = this.$t(
        'INBOX_MGMT.EVOLUTION_API_CONFIG.SCANQRCODE'
      );
      this.interval = setInterval(() => {
        this.sec--;

        if (this.sec < 0) {
          clearInterval(this.interval);
          if (this.connected === true) {
            useAlert(this.$t('INBOX_MGMT.EVOLUTION_API_CONFIG.CONNECT'));
          } else {
            useAlert(this.$t('INBOX_MGMT.EVOLUTION_API_CONFIG.DISCONNECT'));
          }
          this.section1_message = this.$t(
            'INBOX_MGMT.EVOLUTION_API_CONFIG.CONNECTWHATSAPP'
          );
          this.counting = false;
          this.img = false;

          this.status();
        }
      }, 1000);
    },

    async create() {
      this.loading = true;
      const payload = {
        instanceName: this.evoInstanceName,
        token: this.inbox.inbox_identifier,
        qrcode: false,
        integration: 'WHATSAPP-BAILEYS',
        syncFullHistory: this.settings_syncFullHistory,
        groupsIgnore: this.settings_groupsIgnore,
        chatwootAccountId: this.accountId.toString(),
        chatwootToken: this.currentUser.access_token,
        chatwootUrl: this.CHATWOOT_URL,
        chatwootSignMsg: this.chatwootSignMsg,
        chatwootReopenConversation: this.chatwootReopenConversation,
        chatwootConversationPending: this.chatwootConversationPending,
        chatwootImportContacts: this.chatwootImportContacts,
        chatwootImportMessages: this.chatwootImportMessages,
        chatwootMergeBrazilContacts: this.chatwootMergeBrazilContacts,
        chatwootNameInbox: this.inbox.name,
        chatwootDaysLimitImportMessages: this.chatwootDaysLimitImportMessages,
        chatwootOrganization: 'Salez QR-Code',
        chatwootLogo:
          'https://github.com/Salez-Brasil/images/assets/163763817/74ed1e67-b3bd-412b-b3da-5ffcbbf66fc6',
      };

      try {
        const response = await this.request(
          'post',
          `/instance/create`,
          payload
        );
        console.log(response);
        this.status();
      } catch (error) {
        console.error(error);
      } finally {
        this.loading = false;
      }
    },

    async instanceConnect() {
      this.loading = true;
      try {
        const response = await this.request(
          'get',
          `/instance/connect/${this.evoInstanceName}`
        );
        this.img = response.data.base64;
        this.countdown();
      } catch (error) {
        console.error(error);
      } finally {
        this.loading = false;
      }
    },

    async instanceDisconnect() {
      this.loading = true;
      try {
        const response = await this.request(
          'delete',
          `/instance/logout/${this.evoInstanceName}`
        );
        console.log(response);
        this.status();
      } catch (error) {
        console.error(error);
      } finally {
        this.loading = false;
      }
    },

    async setChatwoot() {
      this.loading = true;
      const payload = {
        auto_create: false,
        enabled: true,
        accountId: String(this.accountId),
        token: this.currentUser.access_token,
        url: this.CHATWOOT_URL,
        nameInbox: this.inbox.name,
        signMsg: this.chatwootSignMsg,
        groupsIgnore: this.settings_groupsIgnore,
        syncFullHistory: this.settings_syncFullHistory,
        signDelimiter: '\n',
        reopenConversation: this.chatwootReopenConversation,
        conversationPending: this.chatwootConversationPending,
        mergeBrazilContacts: this.chatwootMergeBrazilContacts,
        importContacts: this.chatwootImportContacts,
        importMessages: this.chatwootImportMessages,
        daysLimitImportMessages: this.chatwootDaysLimitImportMessages,
      };

      try {
        const response = await this.request(
          'post',
          `/chatwoot/set/${this.evoInstanceName}`,
          payload
        );
        console.log(response.data);
        await this.setChatwootWebhook(response.data.webhook_url);
      } catch (error) {
        console.error(error);
      } finally {
        this.loading = false;
      }
    },

    async setSettings() {
      this.loading = true;
      const payload = {
        rejectCall: this.settings_rejectCall,
        msgCall: this.settings_msgCall,
        groupsIgnore: this.settings_groupsIgnore,
        alwaysOnline: this.settings_alwaysOnline,
        readMessages: this.settings_readMessages,
        readStatus: this.settings_readStatus,
        syncFullHistory: this.settings_syncFullHistory,
      };

      try {
        const response = await this.request(
          'post',
          `/settings/set/${this.evoInstanceName}`,
          payload
        );
        console.log(response);
      } catch (error) {
        console.error(error);
      } finally {
        this.loading = false;
      }
    },

    async setChatwootWebhook(webhook_url) {
      try {
        await this.$store.dispatch('inboxes/updateInbox', {
          id: this.inbox.id,
          channel: {
            webhook_url: webhook_url,
          },
        });
        this.$emit('update-webhook', webhook_url);
      } catch (error) {
        console.error(error);
      }
    },
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
};
</script>

<template>
  <div class="flex-1 overflow-auto p-4">
    <SettingsSection
      :title="$t('INBOX_MGMT.EVOLUTION_API_CONFIG.QRCODE')"
      :sub-title="section1_message"
    >
      <woot-submit-button
        v-if="serverStatus && !img && !loading"
        :disabled="connected"
        :button-text="$t('INBOX_MGMT.EVOLUTION_API_CONFIG.CONNECT')"
        @click="instanceConnect"
      />
      <woot-button
        v-if="serverStatus && !img && !loading"
        type="button"
        :disabled="!connected"
        variant="smooth"
        color-scheme="alert"
        @click="instanceDisconnect"
      >
        {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.DISCONNECT') }}
      </woot-button>
      <img v-if="img" :src="img" class="mr-5 rounded-md" />
      <p v-if="img">
        {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.REMAININGTIME') }} {{ sec }} seg.
      </p>
      <div v-if="loading" class="loading-container">
        <div class="spinner-qrcode" />
        <p>{{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.PLEASEWAIT') }}</p>
      </div>
    </SettingsSection>
    <SettingsSection
      v-if="!loading && connected"
      :title="$t('INBOX_MGMT.EVOLUTION_API_CONFIG.OPTIONS')"
      :sub-title="$t('INBOX_MGMT.EVOLUTION_API_CONFIG.CHOOSEOPTIONS')"
      :show-border="false"
    >
      <div class="flex items-center mb-4">
        <woot-switch
          v-model="settings_rejectCall"
          @input="toogleSwitch('settings_rejectCall', settings_rejectCall)"
        />
        <label for="settings_rejectCall"
          >&nbsp; {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.REJECTCALLS') }}</label
        >
      </div>
      <div class="flex items-center mb-4">
        <input
          id="settings_msgCall"
          v-model="settings_msgCall"
          :placeholder="$t('INBOX_MGMT.EVOLUTION_API_CONFIG.DONOTACCEPTCALLS')"
          class="mb-0"
          type="text"
          @blur="toogleSwitch('settings_msgCall', settings_msgCall)"
        />
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="settings_groupsIgnore"
          @input="toogleSwitch('settings_groupsIgnore', settings_groupsIgnore)"
        />
        <label for="settings_groupsIgnore"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.IGNOREGROUPS') }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="settings_alwaysOnline"
          @input="toogleSwitch('settings_alwaysOnline', settings_alwaysOnline)"
        />
        <label for="settings_alwaysOnline"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.ALWAYSONLINE') }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="settings_readMessages"
          @input="toogleSwitch('settings_readMessages', settings_readMessages)"
        />
        <label for="settings_readMessages"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.MARKMESSAGESASREAD') }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="settings_readStatus"
          @input="toogleSwitch('settings_readStatus', settings_readStatus)"
        />
        <label for="settings_readStatus"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.MARKSTATUSASSEEN') }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="settings_syncFullHistory"
          @input="
            toogleSwitch('settings_syncFullHistory', settings_syncFullHistory)
          "
        />
        <label for="settings_syncFullHistory"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.SYNCFULLHISTORY') }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="chatwootSignMsg"
          @input="toogleSwitch('chatwootSignMsg', chatwootSignMsg)"
        />
        <label for="chatwootSignMsg"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.SIGNMESSAGES') }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="chatwootReopenConversation"
          @input="
            toogleSwitch(
              'chatwootReopenConversation',
              chatwootReopenConversation
            )
          "
        />
        <label for="chatwootReopenConversation"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.REOPENCONVERSATIONS') }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="chatwootConversationPending"
          @input="
            toogleSwitch(
              'chatwootConversationPending',
              chatwootConversationPending
            )
          "
        />
        <label for="chatwootConversationPending"
          >&nbsp;
          {{
            $t('INBOX_MGMT.EVOLUTION_API_CONFIG.STARTCONVERSATIONASPENDING')
          }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="chatwootImportContacts"
          @input="
            toogleSwitch('chatwootImportContacts', chatwootImportContacts)
          "
        />
        <label for="chatwootImportContacts"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.IMPORTCONTACTS') }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="chatwootImportMessages"
          @input="
            toogleSwitch('chatwootImportMessages', chatwootImportMessages)
          "
        />
        <label for="chatwootImportMessages"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.IMPORTMESSAGES') }}</label
        >
      </div>
      <div class="flex items-center">
        <woot-switch
          v-model="chatwootMergeBrazilContacts"
          @input="
            toogleSwitch(
              'chatwootMergeBrazilContacts',
              chatwootMergeBrazilContacts
            )
          "
        />
        <label for="chatwootMergeBrazilContacts"
          >&nbsp;
          {{ $t('INBOX_MGMT.EVOLUTION_API_CONFIG.MERGEBRAZILCONTACTS') }}</label
        >
      </div>
    </SettingsSection>
  </div>
</template>

<style scoped>
.loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.spinner-qrcode {
  border: 4px solid rgba(255, 255, 255, 0.1);
  border-top-color: #FF3900;
  border-radius: 50%;
  width: 50px;
  height: 50px;
  animation: spin-qrcode 1s linear infinite;
}

@keyframes spin-qrcode {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}
</style>
