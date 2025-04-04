<template>
  <div class="schedule-message-container">
    <woot-modal
      :show="isFeatureEnabled && show"
      :on-close="onClose"
      :show-close-button="true"
      :close-on-backdrop-click="true"
    >
      <!-- Header do Modal -->
      <div class="modal-header">
        <div class="header-content">
          <div class="title-group">
            <h1 class="modal-title">Agendamento de mensagem</h1>
          </div>
        </div>
      </div>

      <!-- Container dos blocos -->
      <div class="schedule-message">
        <!-- Coluna do Formulário -->
        <div class="form-column">
          <form
            class="schedule-message__form"
            @submit.prevent="handleSubmit"
            @click.stop
          >
            <div class="form-group">
              <label class="dark:text-slate-100">Título</label>
              <input
                v-model="title"
                type="text"
                class="form-input dark:bg-slate-700 dark:text-slate-100 dark:border-slate-600"
                placeholder="Digite um título para o agendamento"
                required
              />
            </div>

            <div class="form-group">
              <label class="dark:text-slate-100">Mensagem</label>
              <textarea
                v-model="message"
                class="form-input dark:bg-slate-700 dark:text-slate-100 dark:border-slate-600"
                placeholder="Digite a mensagem que será enviada"
                required
              />
            </div>

            <div class="form-group">
              <label class="dark:text-slate-100">Selecione o canal</label>
              <select
                v-model="selectedInbox"
                class="form-input dark:bg-slate-700 dark:text-slate-100 dark:border-slate-600"
                required
              >
                <option value="">Selecione o canal</option>
                <option
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </div>

            <div class="form-group">
              <label class="dark:text-slate-100">Selecione a data e horário</label>
              <input
                v-model="scheduledTime"
                type="datetime-local"
                class="form-input dark:bg-slate-700 dark:text-slate-100 dark:border-slate-600"
                required
              />
            </div>

            <div class="modal-footer dark:border-slate-600">
              <div class="button-wrapper">
                <woot-button variant="clear" size="small" @click="onClose">
                  Cancelar
                </woot-button>

                <!-- Botão de Agendar -->
                <woot-button
                  v-if="!isEditing"
                  variant="primary"
                  size="small"
                  color-scheme="success"
                  type="submit"
                >
                  Agendar mensagem
                </woot-button>

                <!-- Botão de Salvar alterações -->
                <woot-button
                  v-else
                  variant="primary"
                  size="small"
                  color-scheme="success"
                  type="button"
                  @click="updateScheduledMessage"
                >
                  Salvar alterações
                </woot-button>
              </div>
            </div>
          </form>
        </div>

        <!-- Coluna da Lista de Agendamentos -->
        <div class="scheduled-list-column">
          <div class="scheduled-messages">
            <div class="scheduled-messages-header">
              <div class="header-content">
                <div class="title-group">
                  <h3 class="dark:text-slate-100">
                    Mensagens agendadas
                    <span v-if="scheduledMessages.length > 0" class="counter">
                      {{ pendingMessagesCount }}
                    </span>
                  </h3>

                  <!-- Filtro apenas se houver mensagens -->
                  <woot-button
                    v-if="scheduledMessages.length > 0"
                    variant="clear"
                    size="small"
                    class="filter-button"
                    @click="openFilterMenu($event)"
                  >
                    <fluent-icon icon="filter" size="16" />
                  </woot-button>
                </div>
              </div>
            </div>

            <!-- Estado vazio -->
            <div v-if="scheduledMessages.length === 0" class="empty-state">
              <div class="empty-state-content">
                <fluent-icon icon="calendar" size="32" class="empty-icon" />
                <p class="empty-text">Ops! Nenhuma mensagem agendada ainda. Vamos agendar? 🙌</p>
                <p class="empty-subtext">
                  As mensagens agendadas aparecerão aqui!
                </p>
              </div>
            </div>

            <!-- Lista de mensagens (existente) -->
            <div v-else class="scheduled-messages-list">
              <div
                v-for="message in filteredMessages"
                :key="message.id"
                class="scheduled-message"
              >
                <!-- Cabeçalho do Card -->
                <div
                  class="message-header"
                  @click="toggleMessageExpand(message.id)"
                >
                  <div class="header-content">
                    <div class="title-section">
                      <div class="title-and-badge">
                        <span class="title">{{ message.title }}</span>
                        <span
                          class="status-badge"
                          :class="getStatusClass(message.status)"
                        >
                          <span class="pulse-dot"></span>
                          {{ getStatusText(message.status) }}
                        </span>
                      </div>
                      <fluent-icon
                        :icon="
                          expandedMessages.includes(message.id)
                            ? 'chevron-up'
                            : 'chevron-down'
                        "
                        size="14"
                        class="expand-icon"
                      />
                    </div>

                    <div class="meta-info">
                      <div class="datetime">
                        <fluent-icon icon="calendar" size="12" class="icon" />
                        {{ formatDate(message.scheduled_at) }}
                      </div>
                      <div class="inbox">
                        <fluent-icon icon="chat" size="12" class="icon" />
                        {{ getInboxName(message.inbox_id) }}
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Conteúdo Expansível -->
                <div
                  v-show="expandedMessages.includes(message.id)"
                  class="message-expandable"
                >
                  <div class="message-preview">
                    <div class="preview-header">
                      <fluent-icon icon="chat" size="14" class="preview-icon" />
                      <span>Mensagem Agendada</span>
                    </div>
                    <div class="preview-content">
                      {{ message.message }}
                    </div>
                  </div>

                  <div class="actions">
                    <woot-button
                      variant="clear"
                      size="small"
                      class="action-button edit"
                      @click.stop.prevent="handleEdit(message)"
                    >
                      <fluent-icon icon="edit" size="12" />
                      Editar
                    </woot-button>
                    <woot-button
                      variant="clear"
                      size="small"
                      class="action-button delete"
                      @click.stop="deleteMessage(message.id)"
                    >
                      <fluent-icon icon="delete" size="12" />
                      Excluir
                    </woot-button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </woot-modal>

    <!-- Modal de Confirmação de Exclusão -->
    <woot-modal
      :show="showDeleteConfirmation"
      :on-close="closeDeleteModal"
      :show-close-button="true"
      :close-on-backdrop-click="true"
    >
      <div class="delete-confirmation-modal">
        <div class="modal-header">
          <div class="header-content">
            <div class="title-group">
              <h1 class="modal-title">Excluir agendamento</h1>
            </div>
          </div>
        </div>

        <div class="modal-content">
          <p class="modal-message">
            Tem certeza que deseja excluir este agendamento? Esta ação não pode
            ser desfeita.
          </p>
        </div>

        <div class="modal-footer">
          <div class="button-wrapper">
            <woot-button variant="clear" size="small" @click="closeDeleteModal">
              Não, manter
            </woot-button>
            <woot-button
              variant="primary"
              color-scheme="alert"
              size="small"
              @click="confirmDelete"
            >
              Sim, excluir
            </woot-button>
          </div>
        </div>
      </div>
    </woot-modal>

    <!-- Adicione isso próximo ao botão de filtro -->
    <context-menu
      :show="showFilterMenu"
      :x="filterMenuPosition.x"
      :y="filterMenuPosition.y"
      :items="filterMenuItems"
      :selected-id="statusFilter"
      @select="handleFilterSelect"
      @close="closeFilterMenu"
    />
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ConversationApi from '../../../../api/inbox/conversation';
import { FEATURE_FLAGS } from '../../../../featureFlags';
import ContextMenu from '../../../ui/ContextMenu.vue';

export default {
  components: {
    ContextMenu,
  },

  props: {
    show: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },

  data() {
    return {
      title: '',
      message: '',
      selectedInbox: '',
      scheduledTime: '',
      isLoading: false,
      scheduledMessages: [],
      isScheduledMessagesOpen: true,
      isEditing: false,
      editingMessageId: null,
      enabledFeatures: {},
      showDeleteConfirmation: false,
      messageToDelete: null,
      expandedMessages: [], // Array para controlar quais mensagens estão expandidas
      statusFilter: 'all', // Novo estado para o filtro
      filterMenuItems: [
        {
          id: 'all',
          label: 'Todos os status',
          icon: 'list',
        },
        {
          id: 'pending',
          label: 'Pendentes',
          icon: 'clock',
        },
        {
          id: 'sent',
          label: 'Enviados',
          icon: 'checkmark',
        },
      ],
      showFilterMenu: false,
      filterMenuPosition: { x: 0, y: 0 },
    };
  },

  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      inboxes: 'inboxes/getInboxes',
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),

    account() {
      return this.$store.getters['accounts/getAccount'](this.accountId);
    },

    isFeatureEnabled() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.SCHEDULE_MESSAGES
      );
    },

    pendingMessagesCount() {
      return this.scheduledMessages.filter(
        message => message.status === 'pending'
      ).length; // Contador de mensagens pendentes
    },

    filteredMessages() {
      if (this.statusFilter === 'all') {
        return this.scheduledMessages;
      }
      return this.scheduledMessages.filter(
        message => message.status === this.statusFilter
      );
    },
  },

  async mounted() {
    console.log(
      '[ScheduleMessageModal] isFeatureEnabled:',
      this.isFeatureEnabled
    );
    console.log('[ScheduleMessageModal] mounted');
    console.log(
      '[ScheduleMessageModal] enabledFeatures:',
      this.enabledFeatures
    );
    console.log(
      '[ScheduleMessageModal] isFeatureEnabled:',
      this.isFeatureEnabled
    );

    await this.fetchScheduledMessages();
    if (!this.isFeatureEnabled) {
      console.log(
        '[ScheduleMessageModal] Feature desabilitada, fechando modal'
      );
      this.onClose();
    }
  },

  methods: {
    initializeEnabledFeatures() {
      this.enabledFeatures = this.account.features;
    },

    async fetchScheduledMessages() {
      try {
        const response = await ConversationApi.getScheduledMessages(
          this.conversationId
        );
        console.log('Resposta da API:', response);

        // Acessando corretamente o array de Mensagens agendadas
        this.scheduledMessages = response.data.payload || [];

        console.log('Mensagens agendadas:', this.scheduledMessages);
      } catch (error) {
        console.error('Erro ao buscar mensagens:', error);
        useAlert('Erro ao carregar Mensagens agendadas', 'error');
      }
    },

    onClose() {
      this.$emit('close');
      this.resetForm();
    },

    resetForm() {
      console.log('Iniciando reset do formulário');
      this.title = '';
      this.message = '';
      this.selectedInbox = '';
      this.scheduledTime = '';
      this.isLoading = false;
      this.isEditing = false;
      this.editingMessageId = null;
      console.log('Formulário resetado');
    },

    async onSubmit() {
      try {
        this.isLoading = true;
        const data = {
          scheduled_message: {
            inbox_id: this.selectedInbox,
            content: this.message,
            scheduled_at: new Date(this.scheduledTime).toISOString(),
            title: this.title,
          },
        };

        await ConversationApi.scheduleMessage({
          conversation_id: this.conversationId,
          ...data.scheduled_message,
        });

        useAlert('Mensagem agendada com sucesso', 'success');
        await this.fetchScheduledMessages();
        this.resetForm();
        this.onClose();
      } catch (error) {
        useAlert(
          'Não foi possível agendar a mensagem. Tente novamente.',
          'error'
        );
      } finally {
        this.isLoading = false;
      }
    },

    async updateScheduledMessage() {
      try {
        this.isLoading = true;
        const data = {
          inbox_id: this.selectedInbox,
          content: this.message,
          scheduled_at: new Date(this.scheduledTime).toISOString(),
          title: this.title,
        };

        await ConversationApi.updateScheduledMessage(
          this.conversationId,
          this.editingMessageId,
          data
        );

        useAlert('Agendamento atualizado com sucesso', 'success');
        await this.fetchScheduledMessages();
        this.resetForm();
        this.onClose();
      } catch (error) {
        useAlert(
          'Não foi possível atualizar o agendamento. Tente novamente.',
          'error'
        );
      } finally {
        this.isLoading = false;
      }
    },

    formatDate(timestamp) {
      return new Date(timestamp * 1000).toLocaleString('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },

    getInboxName(inboxId) {
      const inbox = this.inboxes.find(i => i.id === inboxId);
      return inbox ? inbox.name : 'Caixa não encontrada';
    },

    getStatusText(status) {
      return status === 'sent' ? 'Enviado' : 'Pendente';
    },

    getStatusClass(status) {
      return {
        'status-pending': status === 'pending',
        'status-sent': status === 'sent',
      };
    },

    handleEdit(message) {
      console.log('Preenchendo formulário para edição:', message);

      this.title = message.title;
      this.message = message.message;
      this.selectedInbox = message.inbox_id;

      // Converte o timestamp para o formato datetime-local
      const date = new Date(message.scheduled_at * 1000);
      this.scheduledTime = date.toISOString().slice(0, 16);

      this.isEditing = true;
      this.editingMessageId = message.id;
      this.isScheduledMessagesOpen = false;
    },

    async deleteMessage(id) {
      this.messageToDelete = id;
      this.showDeleteConfirmation = true;
    },

    closeDeleteModal() {
      this.showDeleteConfirmation = false;
      this.messageToDelete = null;
    },

    async confirmDelete() {
      try {
        await ConversationApi.deleteScheduledMessage(
          this.conversationId,
          this.messageToDelete
        );
        await this.fetchScheduledMessages();

        useAlert('Agendamento excluído com sucesso', 'success');
      } catch (error) {
        useAlert('Não foi possível excluir o agendamento', 'error');
      } finally {
        this.closeDeleteModal();
      }
    },

    toggleScheduledMessages() {
      this.isScheduledMessagesOpen = !this.isScheduledMessagesOpen;
    },

    handleSubmit(event) {
      if (!this.isEditing) {
        this.onSubmit();
      }
    },

    toggleMessageExpand(messageId) {
      const index = this.expandedMessages.indexOf(messageId);
      if (index === -1) {
        this.expandedMessages.push(messageId);
      } else {
        this.expandedMessages.splice(index, 1);
      }
    },

    openFilterMenu(event) {
      event.stopPropagation();
      const rect = event.target.getBoundingClientRect();
      this.filterMenuPosition = {
        x: rect.left,
        y: rect.bottom + 4,
      };
      this.showFilterMenu = true;
    },

    closeFilterMenu() {
      this.showFilterMenu = false;
    },

    handleFilterSelect(item) {
      this.statusFilter = item.id;
      this.closeFilterMenu();
    },
  },
};
</script>

<style lang="scss" scoped>
.schedule-message-container {
  // Se necessário, adicione estilos específicos para o container
}

.schedule-message {
  display: flex;
  gap: 24px;
  width: min(90vw, 1200px);
  min-width: 800px;
  height: 80vh;

  .form-column {
    width: 45%;
    min-width: 380px;
    padding: 0 24px 24px;
    border-right: 1px solid;
    overflow-y: auto;
    @apply border-slate-100 dark:border-slate-700;
  }

  .scheduled-list-column {
    width: 55%;
    min-width: 420px;
    padding: 0 24px;
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }
}

.scheduled-messages {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.scheduled-messages-list {
  flex: 1;
  overflow-y: auto;
  margin-top: 12px;
  padding-right: 8px;

  &::-webkit-scrollbar {
    width: 6px;
  }

  &::-webkit-scrollbar-track {
    background: transparent;
  }

  &::-webkit-scrollbar-thumb {
    background-color: rgba(0, 0, 0, 0.2);
    border-radius: 3px;

    @apply dark:bg-slate-600;
  }

  scrollbar-width: thin;

  scrollbar-color: rgba(0, 0, 0, 0.2) transparent;

  .dark & {
    scrollbar-color: rgb(71, 85, 105) transparent;
  }
}

.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease-out;
  max-height: 1000px;
  opacity: 1;
}

.slide-enter-from,
.slide-leave-to {
  max-height: 0;
  opacity: 0;
  overflow: hidden;
}

.message-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 500;

  .status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }

  &.status-pending {
    background-color: #fef3c7;
    color: #92400e;

    .status-dot {
      background-color: #92400e;
    }

    @apply dark:bg-yellow-900 dark:text-yellow-200;

    .status-dot {
      @apply dark:bg-yellow-200;
    }
  }

  &.status-sent {
    background-color: #d1fae5;
    color: #065f46;

    .status-dot {
      background-color: #065f46;
    }

    @apply dark:bg-green-900 dark:text-green-200;

    .status-dot {
      @apply dark:bg-green-200;
    }
  }
}

.scheduled-message {
  background: linear-gradient(145deg, #ffffff 0%, #f8fafc 100%);
  border-radius: 12px;
  margin-bottom: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
  border: 1px solid rgba(0, 0, 0, 0.06);
  transition: all 0.2s ease;
  overflow: hidden;

  &:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  }

  .message-header {
    padding: 12px 14px;
    cursor: pointer;

    .header-content {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }

    .title-section {
      display: flex;
      align-items: center;
      justify-content: space-between;

      .title-and-badge {
        display: flex;
        align-items: center;
        gap: 8px;
      }

      .title {
        font-weight: 500;
        font-size: 13px;
        color: #1a1a1a;
        @apply dark:text-slate-100;
      }

      .expand-icon {
        color: #666;
        @apply dark:text-slate-400;
      }
    }

    .meta-info {
      display: flex;
      align-items: center;
      gap: 12px;
      font-size: 12px;
      color: #666;
      @apply dark:text-slate-400;

      .datetime,
      .inbox {
        display: flex;
        align-items: center;
        gap: 4px;

        .icon {
          color: #1f93ff;
        }
      }
    }
  }

  .message-expandable {
    border-top: 1px solid rgba(0, 0, 0, 0.06);
    @apply dark:border-slate-700;
    animation: slideDown 0.2s ease-out;
  }

  .message-preview {
    padding: 12px;
    background-color: rgba(0, 0, 0, 0.02);
    @apply dark:bg-slate-700/30;

    .preview-header {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-bottom: 6px;
      font-size: 13px;
      font-weight: 500;
      color: #666;
      @apply dark:text-slate-300;

      .preview-icon {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        color: #1f93ff;

        svg {
          width: 14px;
          height: 14px;
        }
      }
    }

    .preview-content {
      padding-left: 20px;
      font-size: 13px;
      line-height: 1.4;
      color: #4a4a4a;
      @apply dark:text-slate-200;
      white-space: pre-wrap;
    }
  }

  .actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    padding: 12px;
    background-color: white;
    border-top: 1px solid rgba(0, 0, 0, 0.06);

    .action-button {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 13px;
      font-weight: 500;
      transition: all 0.2s ease;

      &:hover {
        background-color: rgba(0, 0, 0, 0.05);
      }

      &.edit {
        color: #1f93ff;
      }

      &.delete {
        color: #ff4d4f;
      }
    }
  }

  .status-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 500;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);

    &.status-pending {
      background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
      color: #92400e;

      .pulse-dot {
        background-color: currentColor;
      }

      @apply dark:bg-yellow-900/30 dark:text-yellow-300;
    }

    &.status-sent {
      background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
      color: #065f46;

      .pulse-dot {
        background-color: currentColor;
      }

      @apply dark:bg-green-900/30 dark:text-green-300;
    }

    .pulse-dot {
      width: 4px;
      height: 4px;
      border-radius: 50%;
      animation: pulse 2s infinite;
    }
  }
}

@keyframes pulse {
  0% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(0, 0, 0, 0.4);
  }
  70% {
    transform: scale(1);
    box-shadow: 0 0 0 6px rgba(0, 0, 0, 0);
  }
  100% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(0, 0, 0, 0);
  }
}

@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateY(-8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.dark {
  .scheduled-message {
    background: linear-gradient(145deg, #1e293b 0%, #0f172a 100%);
    border-color: rgba(255, 255, 255, 0.05);

    .actions {
      background-color: #1e293b;
      border-color: rgba(255, 255, 255, 0.1);

      .action-button {
        &:hover {
          background-color: rgba(255, 255, 255, 0.1);
        }

        &.edit {
          color: #60a5fa;
        }

        &.delete {
          color: #ff7875;
        }
      }
    }

    .status-badge {
      &.status-pending {
        background: linear-gradient(
          135deg,
          rgba(234, 179, 8, 0.2) 0%,
          rgba(234, 179, 8, 0.3) 100%
        );
        color: #fbbf24;
      }

      &.status-sent {
        background: linear-gradient(
          135deg,
          rgba(16, 185, 129, 0.2) 0%,
          rgba(16, 185, 129, 0.3) 100%
        );
        color: #34d399;
      }
    }
  }
}

::v-deep .modal-container {
  width: auto !important;
  min-width: auto !important;
  max-width: none !important;
  margin: 2rem;
}

.scheduled-messages-header {
  margin-top: 8px;

  .header-content {
    .title-group {
      display: flex;
      align-items: center;
      justify-content: space-between;
      width: 100%;
      gap: 8px;

      h3 {
        font-size: 14px;
        font-weight: 600;
        display: flex;
        align-items: center;
        gap: 8px;
        margin: 0;

        .counter {
          @apply bg-woot-500 text-white;
          padding: 2px 8px;
          border-radius: 12px;
          font-size: 12px;
          font-weight: 500;
          min-width: 24px;
          text-align: center;
          @apply dark:bg-woot-500 dark:text-white;
        }
      }

      .filter-button {
        padding: 4px;
        border-radius: 4px;
        color: #666;
        @apply dark:text-slate-400;

        &:hover {
          @apply bg-slate-100 dark:bg-slate-700;
        }
      }
    }
  }
}

.modal-header {
  padding: 16px 24px;
  border-bottom: 1px solid;
  @apply border-slate-100 dark:border-slate-700;

  .header-content {
    display: flex;
    align-items: center;
    height: 32px;

    .title-group {
      .modal-title {
        font-size: 18px;
        font-weight: 600;
        @apply text-slate-900 dark:text-slate-50;
        white-space: nowrap;
      }
    }
  }
}

.form-group {
  input[type='datetime-local'] {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid;
    @apply border-slate-200 dark:border-slate-600;
    border-radius: 4px;
    font-size: 14px;
    @apply bg-white dark:bg-slate-700;
    @apply text-slate-900 dark:text-slate-100;

    &:focus {
      outline: none;
      @apply border-woot-500;
      box-shadow: 0 0 0 2px rgba(31, 147, 255, 0.1);
    }

    &::-webkit-calendar-picker-indicator {
      filter: invert(0.5);
      @apply dark:invert;
      cursor: pointer;
      opacity: 0.6;

      &:hover {
        opacity: 1;
      }
    }
  }

  textarea {
    min-height: 120px;
    resize: vertical;
    width: 100%;
    padding: 8px 12px;
    border: 1px solid;
    @apply border-slate-200 dark:border-slate-600;
    border-radius: 4px;
    font-size: 14px;
    @apply bg-white dark:bg-slate-700;
    @apply text-slate-900 dark:text-slate-100;

    &:focus {
      outline: none;
      @apply border-woot-500;
      box-shadow: 0 0 0 2px rgba(31, 147, 255, 0.1);
    }
  }
}

.modal-footer {
  margin-top: 24px;
  padding-top: 16px;
  border-top: 1px solid;
  @apply border-slate-100 dark:border-slate-600;

  .button-wrapper {
    display: flex;
    justify-content: flex-end;
    gap: 8px;

    button {
      min-width: 80px;
    }
  }
}

.delete-confirmation-modal {
  padding: 1.5rem;

  .modal-title {
    font-size: 1.25rem;
    font-weight: 600;
    margin-bottom: 1rem;
    @apply text-slate-900 dark:text-slate-100;
  }

  .modal-message {
    @apply text-slate-700 dark:text-slate-300;
  }

  .modal-footer {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid;
    @apply border-slate-100 dark:border-slate-700;

    .button-wrapper {
      display: flex;
      justify-content: flex-end;
      gap: 0.5rem;
    }
  }
}

.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  padding: 24px;

  .empty-state-content {
    text-align: center;

    .empty-icon {
      margin-bottom: 16px;
      @apply text-slate-400 dark:text-slate-600;
    }

    .empty-text {
      font-size: 14px;
      font-weight: 500;
      margin-bottom: 8px;
      @apply text-slate-700 dark:text-slate-300;
    }

    .empty-subtext {
      font-size: 13px;
      @apply text-slate-500 dark:text-slate-400;
    }
  }
}
</style>
