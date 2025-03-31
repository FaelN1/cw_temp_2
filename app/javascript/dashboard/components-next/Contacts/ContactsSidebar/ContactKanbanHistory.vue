<script setup>
import { ref, computed, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { useStore } from 'vuex';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import KanbanAPI from '../../../api/kanban';

const { t } = useI18n();
const route = useRoute();
const store = useStore();

const conversations = useMapGetter(
  'contactConversations/getAllConversationsByContactId'
);
const contactsById = useMapGetter('contacts/getContactById');
const uiFlags = useMapGetter('contactConversations/getUIFlags');

const isFetching = computed(() => uiFlags.value.isFetching);
const contactConversations = computed(() =>
  conversations.value(route.params.contactId)
);

// Estado para armazenar as atividades do kanban
const kanbanActivities = ref([]);
const loadingKanbanActivities = ref(false);

// Função para formatar data
const formatDate = date => {
  if (!date) return '';
  try {
    return format(new Date(date), 'dd/MM/yyyy HH:mm', { locale: ptBR });
  } catch (error) {
    console.error('Erro ao formatar data:', error);
    return '';
  }
};

// Função para buscar atividades do kanban
const fetchKanbanActivities = async () => {
  if (!contactConversations.value?.length) return;

  loadingKanbanActivities.value = true;
  try {
    const activities = [];

    for (const conversation of contactConversations.value) {
      const response = await KanbanAPI.getItemByConversationId(conversation.id);

      if (response.data && Array.isArray(response.data)) {
        for (const item of response.data) {
          if (item.item_details?.activities) {
            activities.push(
              ...item.item_details.activities.map(activity => ({
                ...activity,
                kanbanItem: {
                  id: item.id,
                  title: item.item_details.title,
                  stage: item.funnel_stage,
                  priority: item.item_details.priority || 'none',
                },
                conversation: {
                  id: conversation.id,
                  title: conversation.meta?.sender?.name || 'Sem nome',
                },
                user: activity.user || {
                  id: null,
                  name: t('UNKNOWN_USER'),
                  avatar_url: '',
                },
              }))
            );
          }
        }
      }
    }

    kanbanActivities.value = activities.sort(
      (a, b) => new Date(b.created_at) - new Date(a.created_at)
    );
  } catch (error) {
    console.error('Erro ao buscar atividades do kanban:', error);
  } finally {
    loadingKanbanActivities.value = false;
  }
};

// Adicione a função para obter dados do usuário
const getUserData = userId => {
  return store.getters['agents/getAgent'](userId);
};

const getIconForActivity = (type, details = {}) => {
  switch (type) {
    case 'attachment_added':
      return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>`;
    case 'note_added':
      return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 20h9M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>`;
    case 'checklist_item_added':
      return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 5v14m-7-7h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>`;
    case 'checklist_item_toggled':
      return details.completed
        ? `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M20 6L9 17l-5-5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>`
        : `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>`;
    case 'stage_changed':
      return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M5 12h14m-7-7l7 7-7 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>`;
    case 'value_changed':
      return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 1v22m5-5H7m10-12H7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>`;
    case 'agent_changed':
      return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2m8-10a4 4 0 100-8 4 4 0 000 8z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>`;
    default:
      return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10zm0-14v4m0 4h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>`;
  }
};

const processedActivities = computed(() => {
  return kanbanActivities.value.map(activity => {
    let icon, title, details;

    switch (activity.type) {
      case 'attachment_added':
        icon = getIconForActivity('attachment_added');
        title = t('HISTORY.ATTACHMENT_ADDED');
        details = activity.details.filename;
        break;

      case 'note_added':
        icon = getIconForActivity('note_added');
        title = t('HISTORY.NOTE_ADDED');
        details = activity.details.note_text;
        break;

      case 'checklist_item_added':
        icon = getIconForActivity('checklist_item_added');
        title = t('HISTORY.CHECKLIST_ITEM_ADDED');
        details = activity.details.item_text;
        break;

      case 'checklist_item_toggled':
        icon = getIconForActivity('checklist_item_toggled', activity.details);
        title = t('HISTORY.CHECKLIST_ITEM_TOGGLED');
        details = `${activity.details.item_text} - ${
          activity.details.completed
            ? t('HISTORY.COMPLETED')
            : t('HISTORY.PENDING')
        }`;
        break;

      case 'stage_changed':
        icon = getIconForActivity('stage_changed');
        title = t('HISTORY.STAGE_CHANGED');
        details = `${activity.details.old_stage || '-'} → ${activity.details.new_stage}`;
        break;

      case 'value_changed':
        icon = getIconForActivity('value_changed');
        title = t('HISTORY.VALUE_CHANGED');
        const oldValue = activity.details.old_value || '0';
        const newValue = activity.details.new_value;
        const currency = activity.details.new_currency?.symbol || 'R$';
        details = `${currency} ${oldValue} → ${currency} ${newValue}`;
        break;

      case 'agent_changed':
        icon = getIconForActivity('agent_changed');
        title = t('HISTORY.AGENT_CHANGED');
        details = activity.details.agent_name || t('KANBAN.NO_AGENT');
        break;

      default:
        icon = getIconForActivity('default');
        title = t('HISTORY.DEFAULT');
        details = '';
    }

    return {
      ...activity,
      icon,
      title,
      details,
    };
  });
});

watch(
  contactConversations,
  () => {
    fetchKanbanActivities();
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col h-full">
    <div
      v-if="isFetching || loadingKanbanActivities"
      class="flex items-center justify-center flex-1 py-10 text-n-slate-11"
    >
      <Spinner />
    </div>
    <div
      v-else-if="processedActivities.length > 0"
      class="flex-1 overflow-y-auto px-6 py-4"
    >
      <div class="space-y-4">
        <div
          v-for="activity in processedActivities"
          :key="activity.id"
          class="history-item relative pl-16"
        >
          <div class="history-connector">
            <div
              class="history-icon"
              v-html="getIconForActivity(activity.type, activity.details)"
            ></div>
          </div>

          <div class="history-content">
            <div class="history-header">
              <div class="flex-1">
                <h4 class="history-title">{{ activity.title }}</h4>
                <p v-if="activity.details" class="history-details">
                  {{ activity.details }}
                </p>
              </div>
              <span class="history-date">{{
                formatDate(activity.created_at)
              }}</span>
            </div>

            <!-- Informações do Kanban Item -->
            <div class="flex items-center gap-2 mb-3">
              <span
                class="px-2 py-0.5 text-xs font-medium rounded-full"
                :class="{
                  'bg-ruby-50 text-ruby-700':
                    activity.kanbanItem.priority === 'high',
                  'bg-yellow-50 text-yellow-700':
                    activity.kanbanItem.priority === 'medium',
                  'bg-green-50 text-green-700':
                    activity.kanbanItem.priority === 'low',
                  'bg-slate-50 text-slate-700':
                    activity.kanbanItem.priority === 'none',
                }"
              >
                {{
                  t(
                    `PRIORITY_LABELS.${activity.kanbanItem.priority.toUpperCase()}`
                  )
                }}
              </span>
              <span class="text-xs text-slate-500">
                {{ activity.kanbanItem.stage }}
              </span>
            </div>

            <!-- Informações da Conversa -->
            <div class="flex items-center gap-2 text-xs text-slate-500">
              <span
                class="inline-flex"
                v-html="
                  `<svg width='12' height='12' viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'>
                <path d='M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2v10z' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/>
              </svg>`
                "
              ></span>
              <span>
                #{{ activity.conversation.id }} -
                {{ activity.conversation.title }}
              </span>
            </div>

            <div class="history-author">
              <Avatar
                :src="activity.user.avatar_url"
                :name="activity.user.name"
                :size="20"
              />
              <span class="text-xs text-slate-600">
                {{ activity.user.name }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    <p
      v-else
      class="flex-1 px-6 py-10 text-sm leading-6 text-center text-n-slate-11"
    >
      {{ t('CONTACTS_LAYOUT.SIDEBAR.KANBAN_HISTORY.EMPTY_STATE') }}
    </p>
  </div>
</template>

<style scoped>
.history-timeline {
  @apply space-y-6;
}

.history-item {
  @apply relative pl-16;
}

.history-connector {
  @apply absolute left-0 top-0 bottom-0 w-16;
}

.history-icon {
  @apply absolute left-0 z-10 flex items-center justify-center w-8 h-8 
         rounded-full bg-white dark:bg-slate-800 border-2 border-woot-500 
         text-woot-500;
}

.history-connector::after {
  content: '';
  @apply absolute left-4 top-8 bottom-0 w-0.5 -translate-x-1/2
         bg-woot-500;
}

.history-item:last-child .history-connector::after {
  @apply hidden;
}

.history-content {
  @apply bg-white dark:bg-slate-800 rounded-lg p-4
         border border-slate-100 dark:border-slate-700
         shadow-sm;
}

.history-header {
  @apply flex items-start justify-between mb-3;
}

.history-title {
  @apply text-sm font-medium text-slate-900 dark:text-slate-100;
}

.history-date {
  @apply text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap;
}

.history-details {
  @apply text-sm text-slate-600 dark:text-slate-400 mb-3;
}

.history-author {
  @apply flex items-center gap-2 pt-3 mt-3 border-t 
         border-slate-100 dark:border-slate-700;
}

.history-text {
  @apply mb-2;
}

.history-icon :deep(svg) {
  @apply w-4 h-4;
}
</style>
