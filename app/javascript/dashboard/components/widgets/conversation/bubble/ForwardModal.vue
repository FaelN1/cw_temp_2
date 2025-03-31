<template>
  <woot-modal modal-type="right-aligned" show :on-close="onClose">
    <div class="forward">
      <div class="forward__title">
        <h1 class="forward__title-primary">Compartilhar mensagem</h1>
        <p class="text-sm text-slate-600 dark:text-slate-400">
          Compartilhe a mensagem com seus contatos
        </p>
      </div>
      <div class="forward__contacts">
        <div class="forward__contacts-search">
          <label
            for="Procurar um contato"
            class="text-sm font-medium mb-1 block"
            >Procurar um contato</label
          >
          <div class="relative">
            <span
              class="absolute inset-y-0 left-0 pl-3 flex items-center text-slate-500"
            >
              <fluent-icon icon="search" size="16" />
            </span>
            <input
              type="search"
              name="contact"
              id="contact"
              class="w-full pl-10 pr-3 py-2 border border-slate-200 dark:border-slate-700 rounded-md bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-woot-500 transition-colors"
              placeholder="Digite o nome ou telefone"
              v-model="searchQuery"
              @keyup.enter="onSearchSubmit"
              @input="onInputSearch"
              @search="resetSearch"
            />
          </div>
        </div>
        <form
          class="form-contact"
          action="#"
          method="post"
          @submit.prevent="onSubmit"
        >
          <div class="forward__contacts-list">
            <div class="contact contact-columns">
              <div class="contact-id">&nbsp;</div>
              <div
                class="contact-name font-medium text-slate-700 dark:text-slate-300"
              >
                Contato
              </div>
              <div
                class="contact-phone font-medium text-slate-700 dark:text-slate-300"
              >
                Telefone
              </div>
              <div
                class="contact-date font-medium text-slate-700 dark:text-slate-300"
              >
                Última Atividade
              </div>
            </div>
            <div class="contacts">
              <div
                v-if="contacts.length === 0 && searchQuery"
                class="empty-state py-8 text-center text-slate-500"
              >
                <fluent-icon
                  icon="search-not-found"
                  size="48"
                  class="mx-auto mb-2 opacity-50"
                />
                <p>Nenhum contato encontrado</p>
              </div>
              <div
                class="contact hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
                v-for="contact in contacts"
                :key="contact.id"
              >
                <div class="contact-id">
                  <label class="flex items-center justify-center h-full">
                    <input
                      type="checkbox"
                      name="contactIds[]"
                      :value="contact.id"
                      class="form-checkbox h-4 w-4 text-woot-500 rounded border-slate-300 dark:border-slate-600 focus:ring-woot-500"
                    />
                  </label>
                </div>
                <div class="contact-name">
                  <div class="contact-thumbnail">
                    <img
                      v-if="contact.thumbnail"
                      :src="contact.thumbnail"
                      :alt="contact.name"
                      class="w-8 h-8 object-cover"
                    />
                    <div
                      v-else
                      class="w-8 h-8 rounded-full bg-woot-50 flex items-center justify-center text-woot-600 font-medium text-sm"
                    >
                      {{
                        contact.name
                          ? contact.name.charAt(0).toUpperCase()
                          : '?'
                      }}
                    </div>
                  </div>
                  <div class="font-medium text-slate-900 dark:text-slate-100">
                    {{ contact.name || 'Sem nome' }}
                  </div>
                </div>
                <div class="contact-phone text-slate-600 dark:text-slate-400">
                  {{ contact.phone_number || '—' }}
                </div>
                <div class="contact-date text-slate-500 dark:text-slate-500">
                  <time-ago
                    :last-activity-timestamp="contact.last_activity_at"
                    :created-at-timestamp="contact.created_at"
                  />
                </div>
              </div>
            </div>
          </div>
          <div class="forward__contacts-footer">
            <woot-button
              :disabled="showEmptySearchResult"
              variant="primary"
              class="px-4 py-2"
            >
              <span class="flex items-center gap-2">
                <fluent-icon icon="share" size="16" />
                Encaminhar
              </span>
            </woot-button>
          </div>
        </form>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import TimeAgo from 'components/ui/TimeAgo.vue';

const DEFAULT_PAGE = 1;

export default {
  components: {
    TimeAgo,
  },
  props: {
    message: {
      type: Object,
    },
  },
  data() {
    return {
      searchQuery: '',
    };
  },
  computed: {
    ...mapGetters({
      contacts: 'contacts/getContacts',
    }),
    showEmptySearchResult() {
      return !!this.searchQuery && this.contacts.length === 0;
    },
  },
  mounted() {
    this.fetchContacts(DEFAULT_PAGE);
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    updatePageParam(page) {
      window.history.pushState({}, null, `${this.$route.path}?page=${page}`);
    },
    fetchContacts(page) {
      this.updatePageParam(page);
      let value = this.searchQuery;
      if (this.searchQuery.charAt(0) === '+') {
        value = this.searchQuery.substring(1);
      }
      const requestParams = {
        page,
        sortAttr: '-last_activity_at',
      };
      if (!value) {
        this.$store.dispatch('contacts/get', requestParams);
      } else {
        this.$store.dispatch('contacts/search', {
          search: encodeURIComponent(value),
          ...requestParams,
        });
      }
    },
    onSearchSubmit() {
      if (!this.searchQuery) return;
      this.fetchContacts(DEFAULT_PAGE);
    },
    onInputSearch(event) {
      const newQuery = event.target.value;
      const refetchAllContacts = !!this.searchQuery && newQuery === '';
      this.searchQuery = newQuery;
      if (refetchAllContacts) {
        this.fetchContacts(DEFAULT_PAGE);
      }
    },
    resetSearch(event) {
      const newQuery = event.target.value;
      if (!newQuery) {
        this.searchQuery = newQuery;
        this.fetchContacts(DEFAULT_PAGE);
      }
    },
    onSubmit(event) {
      const formData = new FormData(event.target);
      const contactIds = formData.getAll('contactIds[]');
      this.$store.dispatch('forwardMessage', {
        conversationId: this.message.conversation_id,
        messageId: this.message.id,
        contacts: contactIds,
      });
      useAlert('Encaminhando mensagem...');
      this.onClose();
    },
  },
};
</script>

<style lang="scss">
.modal-mask .modal--close {
  z-index: 1;
}
.forward {
  padding: 16px;
  position: relative;
  height: 100%;
  min-width: 480px;

  &__title {
    text-align: left;
    margin-bottom: 1.5rem;

    &-primary {
      font-size: 1.5rem;
      font-weight: 600;
      color: var(--color-heading);
      margin-bottom: 0.25rem;
    }
  }

  &__contacts {
    &-search {
      margin-bottom: 1.5rem;

      label {
        color: var(--color-heading);
      }
    }

    .form-contact {
      padding: 0;
    }

    &-list {
      background: var(--white);
      border: 1px solid var(--s-100);
      border-radius: 8px;
      overflow: hidden;

      .contact-columns {
        padding: 8px 0;
        border-bottom: 1px solid var(--s-100);
        background-color: var(--s-50);
      }

      > .contacts {
        overflow-y: auto;
        overflow-x: hidden;
        max-height: calc(100vh - 380px);
        min-height: 200px;

        &::-webkit-scrollbar {
          width: 6px;
        }

        &::-webkit-scrollbar-thumb {
          border-radius: 3px;
          background: var(--s-300);
        }
      }

      .contact {
        display: flex;
        border-bottom: 1px solid var(--s-100);

        &:last-child {
          border-bottom: 0;
        }

        &-id {
          width: 50px;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        &-name {
          display: flex;
          margin: 0 10px;
          align-items: center;
          flex-grow: 1;
          padding: 10px 0;
        }

        &-thumbnail {
          width: 32px;
          height: 32px;
          margin-right: 12px;
          border-radius: 50%;
          overflow: hidden;
          background-color: var(--s-50);
          display: flex;
          align-items: center;
          justify-content: center;

          img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            border-radius: 50%;
          }
        }

        &-phone {
          min-width: 120px;
          display: flex;
          align-items: center;
          padding-right: 8px;
        }

        &-date {
          min-width: 100px;
          display: flex;
          align-items: center;
          padding-right: 16px;

          > .time-ago {
            margin: auto;
          }
        }
      }
    }

    &-footer {
      position: relative;
      padding: 16px 0 0;
      display: flex;
      justify-content: flex-end;
    }
  }
}

// Adicionar variáveis CSS para temas claro e escuro
:root {
  --color-heading: #1f2937;
  --white: #ffffff;
  --s-50: #f8fafc;
  --s-100: #e2e8f0;
  --s-300: #94a3b8;
}

.dark {
  --color-heading: #e2e8f0;
  --white: #1e293b;
  --s-50: #334155;
  --s-100: #475569;
  --s-300: #64748b;
}
</style>
