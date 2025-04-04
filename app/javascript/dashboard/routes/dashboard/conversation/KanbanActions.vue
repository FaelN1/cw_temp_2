<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import KanbanAPI from '../../../api/kanban';
import FunnelAPI from '../../../api/funnel';
import agents from '../../../api/agents';
import KanbanItemForm from '../kanban/components/KanbanItemForm.vue';
import Modal from '../../../components/Modal.vue';
import { format, formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import KanbanItemDetails from '../kanban/components/KanbanItemDetails.vue';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits([]);

const store = useStore();
const kanbanItem = ref(null);
const funnels = ref([]);
const showKanbanForm = ref(false);
const previewData = ref(null);

// Adicione estas refs para controlar o modal de detalhes
const showDetailsModal = ref(false);
const itemToShow = ref(null);

// Adicionar ref para agentsList
const agentsList = ref([]);

// Obtém os dados do contato e conversa atual
const currentChat = computed(() => store.getters.getSelectedChat);
const contactName = computed(
  () => currentChat.value?.meta?.sender?.name || 'Sem nome'
);

// Formata a conversa atual para o select
const currentConversation = computed(() => {
  if (!currentChat.value) return null;

  return {
    id: currentChat.value.id,
    meta: currentChat.value.meta,
    messages: currentChat.value.messages || [],
  };
});

// Watch para mudanças no conversationId
watch(
  () => props.conversationId,
  async (newId, oldId) => {
    if (newId && newId !== oldId) {
      await fetchKanbanItem();
    }
  }
);

const currentFunnel = computed(() => {
  const item = previewData.value || kanbanItem.value;
  if (!item?.funnel_id || !funnels.value.length) return null;
  return funnels.value.find(funnel => funnel.id === item.funnel_id);
});

const kanbanStageLabel = computed(() => {
  const item = previewData.value || kanbanItem.value;
  if (!item || !currentFunnel.value?.stages) return null;
  const stage = currentFunnel.value.stages[item.funnel_stage];
  return stage?.name || item.funnel_stage;
});

const stageStyle = computed(() => {
  const item = previewData.value || kanbanItem.value;
  if (!item || !currentFunnel.value?.stages) return {};
  const stage = currentFunnel.value.stages[item.funnel_stage];
  if (!stage?.color) return {};
  return {
    backgroundColor: `${stage.color}20`,
    color: stage.color,
  };
});

const funnelStyle = computed(() => ({
  backgroundColor: '#64748B20',
  color: '#64748B',
}));

// Dados iniciais para o formulário do Kanban
const initialFormData = computed(() => {
  if (kanbanItem.value) {
    // Se já existe um item, preservar todos os dados existentes
    return {
      ...kanbanItem.value,
      description: kanbanItem.value.item_details?.description || '',
      item_details: {
        ...kanbanItem.value.item_details,
        description: kanbanItem.value.item_details?.description || '',
        _agent: kanbanItem.value.item_details?.agent_id
          ? agentsList.value.find(
              a => a.id === kanbanItem.value.item_details.agent_id
            )
          : null,
      },
      _conversation: currentConversation.value,
    };
  }

  // Se é um novo item, usar os dados da conversa atual
  const assignedAgent = currentChat.value?.meta?.assignee;
  const priority = currentChat.value?.priority || 'none';

  return {
    title: contactName.value,
    description: '',
    funnel_id: funnels.value[0]?.id,
    funnel_stage: 'lead',
    item_details: {
      title: contactName.value,
      description: '',
      conversation_id: props.conversationId,
      agent_id: assignedAgent?.id || null,
      _agent: assignedAgent,
      priority: priority,
    },
    _conversation: currentConversation.value,
  };
});

const fetchFunnels = async () => {
  try {
    const response = await FunnelAPI.get();
    funnels.value = response.data;
  } catch (error) {
    console.error('Erro ao buscar funis:', error);
  }
};

const fetchKanbanItem = async () => {
  try {
    if (!props.conversationId) return;
    const response = await KanbanAPI.getItemByConversationId(
      props.conversationId
    );
    const matchingItem = response.data.find(
      item => item.item_details.conversation_id === props.conversationId
    );
    kanbanItem.value = matchingItem || null;
  } catch (error) {
    console.error('Erro ao buscar item do Kanban:', error);
    kanbanItem.value = null;
  }
};

const handleKanbanFormSave = async item => {
  try {
    // Atualizar o item local antes de fechar o modal
    if (item) {
      kanbanItem.value = {
        ...item,
        item_details: {
          ...item.item_details,
          // Preservar dados que podem não ter sido retornados na resposta
          _agent: item.item_details?.agent_id
            ? agentsList.value.find(a => a.id === item.item_details.agent_id)
            : kanbanItem.value?.item_details?._agent,
          conversation: currentConversation.value,
        },
      };
    }

    showKanbanForm.value = false;
    previewData.value = null;

    // Recarregar os dados do item para garantir sincronização
    await fetchKanbanItem();

    // Emitir evento para atualizar o kanban
    emitter.emit('kanban.item.updated');
  } catch (error) {
    console.error('Erro ao salvar item:', error);
    emitter.emit('newToastMessage', {
      message: 'Erro ao salvar alterações',
      type: 'error',
    });
  }
};

// Adicionar função para carregar agentes
const fetchAgents = async () => {
  try {
    const { data } = await agents.get();
    agentsList.value = data;
  } catch (error) {
    // Tratar erro silenciosamente
  }
};

// Modificar onMounted para incluir carregamento de agentes
onMounted(async () => {
  await Promise.all([fetchFunnels(), fetchAgents(), fetchKanbanItem()]);
});

// New computed properties
const priorityLabel = computed(() => {
  const priority = kanbanItem.value?.item_details?.priority;
  const labels = {
    low: 'Baixa',
    medium: 'Média',
    high: 'Alta',
    urgent: 'Urgente',
    none: 'Nenhuma',
  };
  return labels[priority] || labels.none;
});

const priorityStyle = computed(() => {
  const priority = kanbanItem.value?.item_details?.priority;
  const colors = {
    low: '#10B981',
    medium: '#F59E0B',
    high: '#EF4444',
    urgent: '#7C3AED',
    none: '#64748B',
  };
  const color = colors[priority] || colors.none;
  return {
    backgroundColor: `${color}20`,
    color: color,
  };
});

const hasScheduling = computed(() => {
  return !!(
    kanbanItem.value?.item_details?.deadline_at ||
    kanbanItem.value?.item_details?.scheduled_at
  );
});

// New methods
const formatCurrency = (value, currency) => {
  if (!value) return '-';
  return new Intl.NumberFormat(currency?.locale || 'pt-BR', {
    style: 'currency',
    currency: currency?.code || 'BRL',
  }).format(value);
};

const formatDate = date => {
  if (!date) return '-';
  return format(new Date(date), 'dd/MM/yyyy', { locale: ptBR });
};

const formatDateTime = datetime => {
  if (!datetime) return '-';
  return format(new Date(datetime), "dd/MM/yyyy 'às' HH:mm", { locale: ptBR });
};

// Adicione esta função para formatar o tempo na etapa
const formatTimeInStage = date => {
  if (!date) return '';
  return formatDistanceToNow(new Date(date), {
    locale: ptBR,
    addSuffix: true,
  });
};

// Modifique a função handleShowDetails para usar o item completo
const handleShowDetails = item => {
  // Certifique-se de que o item tem todas as propriedades necessárias
  const formattedItem = {
    ...item,
    title: item.item_details?.title || contactName.value,
    description: item.item_details?.description || '',
    priority: item.item_details?.priority || 'none',
    funnel_stage: item.funnel_stage,
    item_details: {
      ...item.item_details,
      priority: item.item_details?.priority || 'none',
    },
  };

  itemToShow.value = formattedItem;
  showDetailsModal.value = true;
};

// Adicione esta função para atualizar os dados quando o modal for fechado
const handleDetailsUpdate = async () => {
  await fetchKanbanItem();
};
</script>

<template>
  <div class="p-4">
    <div v-if="kanbanItem && currentFunnel" class="flex flex-col gap-4">
      <!-- Funnel and Stage Section -->
      <div
        class="flex flex-col gap-3 p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg"
      >
        <div class="flex items-center justify-between">
          <span class="text-slate-600 dark:text-slate-400 text-sm font-medium"
            >Funil:</span
          >
          <span
            class="text-xs font-medium px-3 py-1 rounded-full"
            :style="funnelStyle"
          >
            {{ currentFunnel.name }}
          </span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-slate-600 dark:text-slate-400 text-sm font-medium"
            >Etapa:</span
          >
          <span
            class="text-xs font-medium px-3 py-1 rounded-full"
            :style="stageStyle"
          >
            {{ kanbanStageLabel }}
          </span>
        </div>

        <!-- Time in stage -->
        <div
          v-if="kanbanItem.stage_entered_at"
          class="flex items-center justify-between mt-1 py-2 px-3 bg-woot-500 dark:bg-woot-600 rounded"
        >
          <span class="text-white text-xs"> Tempo na etapa </span>
          <span class="text-xs font-medium text-white">
            {{ formatTimeInStage(kanbanItem.stage_entered_at) }}
          </span>
        </div>
      </div>

      <!-- Details Section -->
      <div
        class="flex flex-col gap-3 p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-dashed border-woot-500/50 dark:border-woot-400/50"
      >
        <div
          v-if="kanbanItem.item_details.value"
          class="flex items-center justify-between"
        >
          <span class="text-slate-600 dark:text-slate-400 text-sm font-medium"
            >Valor:</span
          >
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-200"
          >
            {{
              formatCurrency(
                kanbanItem.item_details.value,
                kanbanItem.item_details.currency
              )
            }}
          </span>
        </div>

        <div class="flex items-center justify-between">
          <span class="text-slate-600 dark:text-slate-400 text-sm font-medium"
            >Prioridade:</span
          >
          <span
            class="text-xs font-medium px-3 py-1 rounded-full"
            :style="priorityStyle"
          >
            {{ priorityLabel }}
          </span>
        </div>

        <div v-if="hasScheduling" class="flex flex-col gap-2">
          <div
            v-if="kanbanItem.item_details.deadline_at"
            class="flex items-center justify-between"
          >
            <span
              class="text-slate-600 dark:text-slate-400 text-sm font-medium flex items-center gap-1"
            >
              <i class="icon-calendar-clock text-base align-text-bottom"></i>
              Prazo:
            </span>
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{ formatDate(kanbanItem.item_details.deadline_at) }}
            </span>
          </div>
          <div
            v-if="kanbanItem.item_details.scheduled_at"
            class="flex items-center justify-between"
          >
            <span
              class="text-slate-600 dark:text-slate-400 text-sm font-medium flex items-center gap-1"
            >
              <i class="icon-calendar text-base align-text-bottom"></i>
              Agendado:
            </span>
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{ formatDateTime(kanbanItem.item_details.scheduled_at) }}
            </span>
          </div>
        </div>
      </div>

      <!-- Notes Section -->
      <div
        v-if="kanbanItem.item_details.notes?.length"
        class="flex flex-col gap-3"
      >
        <div class="flex items-center gap-2">
          <i class="icon-message-square text-slate-600 dark:text-slate-400"></i>
          <span class="text-slate-600 dark:text-slate-400 text-sm font-medium"
            >Notas</span
          >
        </div>
        <div class="flex flex-col gap-3">
          <div
            v-for="note in kanbanItem.item_details.notes"
            :key="note.id"
            class="bg-white dark:bg-slate-800 p-4 rounded-lg border border-slate-100 dark:border-slate-700 shadow-sm"
          >
            <div class="flex items-center gap-2 mb-2">
              <span
                class="text-xs font-medium text-slate-700 dark:text-slate-300 bg-slate-100 dark:bg-slate-700 px-2 py-1 rounded"
              >
                {{ note.author }}
              </span>
              <span class="text-xs text-slate-500">
                {{ formatDateTime(note.created_at) }}
              </span>
            </div>
            <p
              class="text-sm text-slate-700 dark:text-slate-200 whitespace-pre-wrap"
            >
              {{ note.text }}
            </p>
          </div>
        </div>
      </div>

      <!-- Action Button -->
      <div class="flex justify-center gap-2 mt-2">
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          class="w-full sm:w-auto"
          @click="showKanbanForm = true"
        >
          <i class="icon-edit-2 mr-1"></i>
          Atualizar Funil
        </woot-button>

        <woot-button
          variant="smooth"
          color-scheme="primary"
          size="small"
          class="w-full sm:w-auto"
          @click="handleShowDetails(kanbanItem)"
        >
          <fluent-icon icon="info" size="16" class="mr-1" />
          Ver Detalhes
        </woot-button>
      </div>
    </div>

    <!-- Empty State -->
    <div
      v-else
      class="flex flex-col items-center justify-center gap-4 text-center p-6 bg-slate-50 dark:bg-slate-800/50 rounded-lg"
    >
      <i class="icon-funnel text-3xl text-slate-400 dark:text-slate-500"></i>
      <p class="text-sm text-slate-500 dark:text-slate-400">
        Nenhuma etapa do pipeline associado
      </p>
      <woot-button
        variant="smooth"
        color-scheme="primary"
        size="small"
        @click="showKanbanForm = true"
      >
        <i class="icon-plus mr-1"></i>
        Definir pipeline
      </woot-button>
    </div>

    <!-- Modal -->
    <Modal
      v-model:show="showKanbanForm"
      size="full-width"
      :on-close="
        () => {
          showKanbanForm = false;
          previewData.value = null;
        }
      "
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4 flex items-center gap-2">
          <i class="icon-funnel text-slate-600 dark:text-slate-400"></i>
         {{ kanbanItem ? 'Editar item do pipeline' : 'Criar item do pipeline' }}
        </h3>
        <KanbanItemForm
          v-if="funnels[0]"
          :funnel-id="initialFormData.funnel_id || funnels[0].id"
          :stage="initialFormData.funnel_stage || 'lead'"
          :initial-data="initialFormData"
          :is-editing="!!kanbanItem"
          :current-conversation="currentConversation"
          @saved="handleKanbanFormSave"
          @close="showKanbanForm = false"
          @update:preview="newData => (previewData.value = newData)"
        />
      </div>
    </Modal>

    <!-- Modal de Detalhes -->
    <Modal
      v-model:show="showDetailsModal"
      size="full-width"
      :on-close="
        () => {
          showDetailsModal = false;
          itemToShow.value = null;
          handleDetailsUpdate();
        }
      "
    >
      <KanbanItemDetails
        v-if="itemToShow"
        :item="itemToShow"
        @close="
          () => {
            showDetailsModal = false;
            itemToShow.value = null;
            handleDetailsUpdate();
          }
        "
        @edit="
          () => {
            showDetailsModal = false;
            showKanbanForm = true;
          }
        "
        @item-updated="handleDetailsUpdate"
      />
    </Modal>
  </div>
</template>
