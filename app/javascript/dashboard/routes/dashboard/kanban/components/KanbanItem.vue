<script setup>
import {
  computed,
  ref,
  watch,
  nextTick,
  onMounted,
  onUnmounted,
  inject,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import CustomContextMenu from 'dashboard/components/ui/CustomContextMenu.vue';
import Modal from 'dashboard/components/Modal.vue';
import SendMessageTemplate from './SendMessageTemplate.vue';
import KanbanAPI from '../../../../api/kanban';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  item: {
    type: Object,
    required: true,
  },
  isDragging: {
    type: Boolean,
    default: false,
  },
  draggable: {
    type: Boolean,
    default: false,
  },
  kanbanItems: {
    type: Array,
    default: () => [],
  },
});

// Injetar o map de labels fornecido pelo componente pai
const labelsMap = inject('labelsMap', {});

const emit = defineEmits([
  'click',
  'edit',
  'delete',
  'dragstart',
  'conversationUpdated',
]);

const router = useRouter();
const { t } = useI18n();

// Ref para armazenar os dados da conversa - simplificado para usar diretamente do item
const conversationData = computed(() => {
  return props.item.item_details?.conversation || null;
});

const priorityInfo = computed(() => {
  // Buscar prioridade do item_details
  const priority = props.item.item_details?.priority?.toLowerCase() || 'none';

  // Se for none, retorna null para não exibir o badge
  if (priority === 'none') return null;

  const priorityMap = {
    high: {
      label: t('PRIORITY.HIGH'),
      class: 'bg-ruby-50 dark:bg-ruby-800 text-ruby-800 dark:text-ruby-50',
    },
    medium: {
      label: t('KANBAN.PRIORITY_LABELS.MEDIUM'),
      class:
        'bg-yellow-50 dark:bg-woot-120 text-yellow-800 dark:text-yellow-50',
    },
    low: {
      label: t('KANBAN.PRIORITY_LABELS.LOW'),
      class: 'bg-green-50 dark:bg-green-800 text-green-800 dark:text-green-50',
    },
  };

  return priorityMap[priority] || null;
});

const formattedDate = computed(() => {
  const dateStr = props.item.created_at || props.item.createdAt;
  if (!dateStr) return '';

  try {
    const date = new Date(dateStr);
    return t('KANBAN.CREATED_AT_FORMAT', {
      date: new Intl.DateTimeFormat('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      }).format(date),
    });
  } catch (error) {
    console.error('Erro ao formatar data:', error);
    return '';
  }
});

const formattedValue = computed(() => {
  const value = props.item.item_details?.value;
  const currency = props.item.item_details?.currency;

  if (!value && value !== 0) return null;

  try {
    return new Intl.NumberFormat(currency?.locale || 'pt-BR', {
      style: 'currency',
      currency: currency?.code || 'BRL',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(value);
  } catch (error) {
    return value.toString();
  }
});

const formattedDeadline = computed(() => {
  const deadline = props.item.item_details?.deadline_at;
  const scheduled = props.item.item_details?.scheduled_at;
  const schedulingType = props.item.item_details?.scheduling_type;

  if (!deadline && !scheduled) return null;

  try {
    const dateStr = scheduled || deadline;
    const date = new Date(dateStr);

    if (!Number.isFinite(date.getTime())) {
      return null;
    }

    const dateFormatter = new Intl.DateTimeFormat('pt-BR', {
      dateStyle: 'short',
      ...(schedulingType === 'schedule' && scheduled
        ? { timeStyle: 'short' }
        : {}),
    });

    return dateFormatter.format(date);
  } catch (error) {
    return null;
  }
});

const scheduleIcon = computed(() => {
  const schedulingType = props.item.item_details?.scheduling_type;
  return schedulingType === 'schedule' ? 'calendar' : 'alarm';
});

const truncatedTitle = computed(() => {
  const titleValue = props.item.item_details?.title || '';
  if (titleValue.length > 15) {
    return `${titleValue.substring(0, 15)}...`;
  }
  return titleValue;
});

const truncatedSenderName = computed(() => {
  const name = conversationData.value?.contact?.name;
  const email = conversationData.value?.contact?.email;
  const defaultText = t('ITEM_CONVERSATION.NO_CONTACT');
  const text = name || email || defaultText;

  return text.length > 25 ? `${text.substring(0, 25)}...` : text;
});

const handleClick = () => {
  console.log('[DEBUG KanbanItem] handleClick - Iniciando...');
  console.log('[DEBUG KanbanItem] handleClick - Item clicado:', props.item);
  emit('click', props.item);
};

const handleEdit = e => {
  e.stopPropagation();
  console.log('[DEBUG KanbanItem] Emitindo evento edit com item:', props.item);
  console.log(
    '[DEBUG KanbanItem] Item priority:',
    props.item.item_details?.priority
  );
  console.log('[DEBUG KanbanItem] Item details:', props.item.item_details);
  emit('edit', props.item);
};

// Adicionar ref para controlar o modal
const showDeleteModal = ref(false);
const itemToDelete = ref(null);

// Modificar o método de delete para mostrar o modal primeiro
const handleDelete = e => {
  e.stopPropagation();
  itemToDelete.value = props.item;
  showDeleteModal.value = true;
};

// Adicionar método para confirmar a exclusão
const confirmDelete = () => {
  emit('delete', itemToDelete.value);
  showDeleteModal.value = false;
  itemToDelete.value = null;
};

// Função para navegar para a conversa
const navigateToConversation = (e, conversationId) => {
  e.stopPropagation(); // Previne a propagação do clique para o card

  if (!conversationId || !conversationData.value) return;

  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: conversationData.value.account_id,
      inboxId: conversationData.value.inbox_id,
      conversation_id: conversationId,
    },
  });
};

// Adicione essas novas refs e funções
const showContextMenu = ref(false);
const contextMenuPosition = ref({ x: 0, y: 0 });

const handleContextMenu = (e, conversationId) => {
  if (!conversationId || !conversationData.value) return;

  e.preventDefault();
  showContextMenu.value = true;
  contextMenuPosition.value = {
    x: e.clientX,
    y: e.clientY,
  };
};

const showSendMessageModal = ref(false);

const handleQuickMessage = () => {
  try {
    nextTick(() => {
      showContextMenu.value = false;
      showSendMessageModal.value = true;
    });
  } catch (error) {
    console.error('Erro ao processar clique:', error);
  }
};

const handleSendMessage = ({ template, conversationId }) => {
  showSendMessageModal.value = false;
};

const handleViewContact = () => {
  // Fecha o menu de contexto
  showContextMenu.value = false;

  // Verifica se temos os dados necessários
  if (!conversationData.value?.contact?.id) {
    return;
  }

  try {
    // Navega para a página do contato
    router.push({
      name: 'contact_profile',
      params: {
        accountId: conversationData.value.account_id,
        contactId: conversationData.value.contact.id,
      },
      query: {
        page: 1,
      },
    });
  } catch (err) {
    // Fallback: navegação direta pela URL
    window.location.href = `/app/accounts/${conversationData.value.account_id}/contacts/${conversationData.value.contact.id}?page=1`;
  }
};

const handleDragStart = e => {
  emit('dragstart', e);
};

// Adicionar watch para monitorar mudanças
watch(showSendMessageModal, newValue => {
  console.log('Modal status alterado:', newValue);
  if (!newValue) {
    nextTick(() => {
      showContextMenu.value = false;
    });
  }
});

// Adicione essa nova ref
const showFullDescription = ref(false);

// Adicione esse novo computed
const truncatedDescription = computed(() => {
  const description =
    props.item.item_details?.description || t('KANBAN.NO_DESCRIPTION');
  if (description.length <= 75 || showFullDescription.value) {
    return description;
  }
  return description.substring(0, 75) + '...';
});

// Adicione essa nova função
const toggleDescription = e => {
  e.stopPropagation();
  showFullDescription.value = !showFullDescription.value;
};

const handleFilter = filters => {
  const filteredItems = props.kanbanItems.filter(item => {
    // Lógica de filtro aqui
  });
  emit('filter', filteredItems);
};

// Modificar computed agentInfo
const agentInfo = computed(() => {
  // Agora apenas busca do agente incluído nos item_details
  if (props.item.item_details?.agent) {
    return {
      id: props.item.item_details.agent.id,
      name: props.item.item_details.agent.name,
      avatar_url: props.item.item_details.agent.avatar_url || '',
    };
  }

  return null;
});

// Adicionar nova ref para controlar o menu de opções
const showOptionsMenu = ref(false);

// Fechar menu ao clicar fora
onMounted(() => {
  document.addEventListener('click', () => {
    showOptionsMenu.value = false;
  });

  // Carregar configurações de visibilidade
  const allSettings = JSON.parse(
    localStorage.getItem('kanban_items_visibility') || '{}'
  );
  const itemSettings = allSettings[props.item.id];

  if (itemSettings) {
    try {
      showDescriptionField.value = itemSettings.showDescriptionField ?? true;
      showLabelsField.value = itemSettings.showLabelsField ?? true;
      showPriorityField.value = itemSettings.showPriorityField ?? true;
      showValueField.value = itemSettings.showValueField ?? true;
      showDeadlineField.value = itemSettings.showDeadlineField ?? true;
      showConversationField.value = itemSettings.showConversationField ?? true;
      showChecklistField.value = itemSettings.showChecklistField ?? true;
      showAgentField.value = itemSettings.showAgentField ?? true;
      showMetadataField.value = itemSettings.showMetadataField ?? true;
    } catch (error) {
      console.error('Erro ao carregar configurações de visibilidade:', error);
    }
  }

  // Carregar estado de colapso
  loadCollapsedState();

  // Adicionar listener para evento global
  emitter.on('kanbanItemsCollapsedStateChanged', loadCollapsedState);
});

onUnmounted(() => {
  document.removeEventListener('click', () => {
    showOptionsMenu.value = false;
  });

  // Remover o listener ao desmontar o componente
  emitter.off('kanbanItemsCollapsedStateChanged', loadCollapsedState);
});

// Função para carregar o estado de colapso do localStorage
const loadCollapsedState = () => {
  const collapsedItems = JSON.parse(
    localStorage.getItem('kanban_collapsed_items') || '{}'
  );

  if (props.item.id in collapsedItems) {
    isItemCollapsed.value = collapsedItems[props.item.id];
  }
};

const showStatusModal = ref(false);
const statusForm = ref({
  status: '',
  reason: '',
});

const handleStatusClick = () => {
  // Inicializa o form com o status atual
  statusForm.value = {
    status: props.item.item_details?.status || '',
    reason: props.item.item_details?.reason || '',
  };

  showStatusModal.value = true;
};

const handleStatusSave = async () => {
  try {
    const updatedItem = {
      ...props.item,
      item_details: {
        ...props.item.item_details,
        status: statusForm.value.status,
        reason:
          statusForm.value.status === 'lost' ? statusForm.value.reason : null,
      },
    };

    const { data } = await KanbanAPI.update(props.item.id, updatedItem);

    // Atualiza o item localmente para refletir as mudanças imediatamente
    if (data) {
      Object.assign(props.item, data);
    }

    showStatusModal.value = false;
    emit('conversationUpdated');
  } catch (error) {
    console.error('Erro ao atualizar status:', error);
  }
};

// Adicione este computed
const getStatusLabel = computed(() => {
  const status = props.item.item_details?.status;

  if (!status) return t('KANBAN.BULK_ACTIONS.ITEM_STATUS.OPEN');

  if (status === 'won') {
    const date = new Date(
      props.item.item_details?.updated_at
    ).toLocaleDateString();
    return t('KANBAN.BULK_ACTIONS.ITEM_STATUS.WON');
  }

  if (status === 'lost') {
    const date = new Date(
      props.item.item_details?.updated_at
    ).toLocaleDateString();
    return t('KANBAN.BULK_ACTIONS.ITEM_STATUS.LOST');
  }

  return 'Status';
});

// Atualiza o computed para buscar anexos de todas as fontes
const attachmentsCount = computed(() => {
  const itemAttachments = props.item.attachments?.length || 0;
  const itemDetailsAttachments =
    props.item.item_details?.attachments?.length || 0;
  const noteAttachments =
    props.item.item_details?.notes?.reduce((count, note) => {
      return count + (note.attachments?.length || 0);
    }, 0) || 0;

  return itemAttachments + itemDetailsAttachments + noteAttachments;
});

const notesCount = computed(() => {
  return props.item.item_details?.notes?.length || 0;
});

// Adiciona computed properties para o progresso do checklist
const totalItems = computed(() => {
  return props.item.item_details?.checklist?.length || 0;
});

const completedItems = computed(() => {
  return (
    props.item.item_details?.checklist?.filter(item => item.completed)
      ?.length || 0
  );
});

const checklistProgress = computed(() => {
  if (totalItems.value === 0) return 0;
  return (completedItems.value / totalItems.value) * 100;
});

// Adicione uma computed property para o tempo na etapa
const timeInStage = computed(() => {
  if (!props.item.stage_entered_at) return '';

  try {
    const formattedTime = formatDistanceToNow(
      new Date(props.item.stage_entered_at),
      {
        locale: ptBR,
        addSuffix: false,
      }
    );

    // Remove todos os prefixos e o termo "cerca"
    return formattedTime
      .replace(/^há cerca de /i, '')
      .replace(/^há /i, '')
      .replace(/cerca de /i, '')
      .replace(/cerca/i, '');
  } catch (error) {
    return '';
  }
});

// Adicione este computed
const conversationLabels = computed(() => {
  return props.item.item_details?.conversation?.label_list || [];
});

// Adicione esta função helper para escurecer cores
const darkenColor = (color, amount = 0.2) => {
  try {
    if (!color) return '#64748B';

    // Remove o # se existir
    const hex = color.replace('#', '');

    // Converte para RGB
    const r = parseInt(hex.substring(0, 2), 16);
    const g = parseInt(hex.substring(2, 4), 16);
    const b = parseInt(hex.substring(4, 6), 16);

    // Escurece cada componente
    const darkerR = Math.floor(r * (1 - amount));
    const darkerG = Math.floor(g * (1 - amount));
    const darkerB = Math.floor(b * (1 - amount));

    // Converte de volta para hex
    return `#${darkerR.toString(16).padStart(2, '0')}${darkerG.toString(16).padStart(2, '0')}${darkerB.toString(16).padStart(2, '0')}`;
  } catch {
    return '#64748B';
  }
};

// Adicione este computed
const contactAvatar = computed(() => {
  return props.item.item_details?.conversation?.contact?.thumbnail || '';
});

// Adicione estas refs para controlar a visibilidade dos campos
const showDescriptionField = ref(true);
const showLabelsField = ref(true);
const showPriorityField = ref(true);
const showValueField = ref(true);
const showDeadlineField = ref(true);
const showConversationField = ref(true);
const showChecklistField = ref(true);
const showAgentField = ref(true);
const showMetadataField = ref(true);

// Adicionar ref para controlar o estado expandido/colapsado
const isItemCollapsed = ref(false);

// Adicione este ref e função para controlar o modal de visibilidade
const showVisibilityModal = ref(false);

const handleVisibilityClick = () => {
  showOptionsMenu.value = false;
  showVisibilityModal.value = true;
};

// Função para alternar entre expandido/colapsado
const toggleCollapseItem = () => {
  isItemCollapsed.value = !isItemCollapsed.value;
  saveItemCollapsedState();
  showOptionsMenu.value = false;
};

// Função para salvar o estado de colapso no localStorage
const saveItemCollapsedState = () => {
  const collapsedItems = JSON.parse(
    localStorage.getItem('kanban_collapsed_items') || '{}'
  );
  collapsedItems[props.item.id] = isItemCollapsed.value;
  localStorage.setItem(
    'kanban_collapsed_items',
    JSON.stringify(collapsedItems)
  );
};

// Função para salvar configurações no localStorage
const saveFieldVisibility = () => {
  const settings = {
    showDescriptionField: showDescriptionField.value,
    showLabelsField: showLabelsField.value,
    showPriorityField: showPriorityField.value,
    showValueField: showValueField.value,
    showDeadlineField: showDeadlineField.value,
    showConversationField: showConversationField.value,
    showChecklistField: showChecklistField.value,
    showAgentField: showAgentField.value,
    showMetadataField: showMetadataField.value,
  };

  // Carregar configurações existentes
  const allSettings = JSON.parse(
    localStorage.getItem('kanban_items_visibility') || '{}'
  );

  // Atualizar apenas as configurações deste item específico
  allSettings[props.item.id] = settings;

  // Salvar de volta no localStorage
  localStorage.setItem('kanban_items_visibility', JSON.stringify(allSettings));
};

// Observe as mudanças em todas as configurações de visibilidade
watch(
  [
    showDescriptionField,
    showLabelsField,
    showPriorityField,
    showValueField,
    showDeadlineField,
    showConversationField,
    showChecklistField,
    showAgentField,
    showMetadataField,
  ],
  () => {
    saveFieldVisibility();
  }
);
</script>

<template>
  <div
    class="flex flex-col p-4 bg-white dark:bg-slate-900 rounded-lg border border-slate-100 dark:border-slate-800 shadow-sm hover:shadow-md transition-shadow cursor-pointer mt-3"
    :class="{ 'opacity-50': isDragging }"
    :draggable="draggable"
    @dragstart="handleDragStart"
    @click="handleClick"
  >
    <div class="flex items-center justify-between mb-3">
      <div class="flex items-center gap-2">
        <!-- Avatar do contato -->
        <Avatar
          v-if="contactAvatar"
          :src="contactAvatar"
          :name="truncatedTitle"
          :size="24"
        />

        <div class="flex items-center gap-2">
          <h3 class="text-sm font-medium text-slate-900 dark:text-slate-100">
            {{ truncatedTitle }}
          </h3>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <div class="flex items-center gap-2">
          <!-- Status Badge -->
          <button
            class="px-2 py-1 text-xs font-medium rounded-full flex items-center gap-1 transition-colors"
            :class="{
              'bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-300':
                !props.item.item_details?.status,
              'bg-green-50 text-green-700 dark:bg-green-900 dark:text-green-300':
                props.item.item_details?.status === 'won',
              'bg-red-50 text-red-700 dark:bg-red-900 dark:text-red-300':
                props.item.item_details?.status === 'lost',
            }"
            @click.stop="handleStatusClick"
          >
            <svg
              v-if="props.item.item_details?.status"
              xmlns="http://www.w3.org/2000/svg"
              width="12"
              height="12"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="w-3 h-3"
            >
              <polyline points="20 6 9 17 4 12"></polyline>
            </svg>
            <span>
              {{ getStatusLabel }}
            </span>
          </button>

          <!-- More Options Button -->
          <div class="relative">
            <button
              class="p-1 rounded-full hover:bg-slate-100 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
              @click.stop="showOptionsMenu = !showOptionsMenu"
            >
              <fluent-icon icon="more-vertical" size="16" />
            </button>

            <!-- Menu de Opções -->
            <div
              v-if="showOptionsMenu"
              class="absolute right-0 top-full mt-1 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-1 w-[180px] z-10"
              @click.stop
            >
              <button
                class="w-full px-4 py-2 text-left text-sm hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200"
                @click.stop="handleEdit($event)"
              >
                <span class="flex items-center gap-2">
                  <fluent-icon icon="edit" size="16" />
                  {{ t('KANBAN.ACTIONS.EDIT') }}
                </span>
              </button>
              <button
                class="w-full px-4 py-2 text-left text-sm hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200"
                @click.stop="handleVisibilityClick"
              >
                <span class="flex items-center gap-2">
                  <fluent-icon icon="eye-show" size="16" />
                  {{ t('KANBAN.CONTEXT_MENU.CUSTOMIZE_FIELDS') }}
                </span>
              </button>
              <button
                class="w-full px-4 py-2 text-left text-sm hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200"
                @click.stop="toggleCollapseItem"
              >
                <span class="flex items-center gap-2">
                  <fluent-icon
                    :icon="isItemCollapsed ? 'arrow-expand' : 'arrow-outwards'"
                    size="16"
                  />
                  {{
                    isItemCollapsed
                      ? t('KANBAN.CONTEXT_MENU.EXPAND')
                      : t('KANBAN.CONTEXT_MENU.COLLAPSE')
                  }}
                </span>
              </button>
              <button
                class="w-full px-4 py-2 text-left text-sm hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200"
                @click.stop="handleDelete($event)"
              >
                <span class="flex items-center gap-2">
                  <fluent-icon icon="delete" size="16" />
                  {{ t('KANBAN.ACTIONS.DELETE') }}
                </span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <p
      v-if="showDescriptionField"
      class="text-xs text-slate-600 dark:text-slate-400 mb-3"
    >
      {{ truncatedDescription }}
      <span
        v-if="(props.item.item_details?.description || '').length > 75"
        class="text-xs font-medium text-woot-500 dark:text-woot-400 hover:underline cursor-pointer inline-block mt-1"
        @click="toggleDescription"
      >
        {{
          showFullDescription ? t('KANBAN.READ_LESS') : t('KANBAN.READ_MORE')
        }}
      </span>
    </p>

    <!-- Adicione as tags aqui -->
    <div
      v-if="
        showLabelsField && !isItemCollapsed && conversationLabels.length > 0
      "
      class="flex flex-wrap gap-1 mb-3"
    >
      <span
        v-for="label in conversationLabels"
        :key="label"
        class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
        :style="{
          backgroundColor: labelsMap[label]
            ? `${labelsMap[label]}20`
            : '#E2E8F0',
          color: darkenColor(labelsMap[label]),
        }"
      >
        {{ label }}
      </span>
    </div>

    <!-- Modifique a seção de valor e prazo -->
    <div
      v-if="
        (showPriorityField || showValueField || showDeadlineField) &&
        !isItemCollapsed
      "
      class="flex items-center justify-between mb-3"
    >
      <div class="flex items-center gap-2">
        <!-- Badge de Prioridade - Só exibe se não for 'none' -->
        <span
          v-if="
            showPriorityField &&
            props.item.item_details?.priority &&
            props.item.item_details.priority !== 'none'
          "
          class="px-2 py-1 text-xs font-medium rounded-full"
          :class="priorityInfo.class"
        >
          {{ priorityInfo.label }}
        </span>

        <!-- Valor -->
        <span
          v-if="showValueField && formattedValue"
          class="text-xs font-medium text-slate-700 dark:text-slate-300"
        >
          {{ formattedValue }}
        </span>
      </div>

      <!-- Prazo -->
      <div
        v-if="showDeadlineField && formattedDeadline"
        class="flex items-center gap-1"
      >
        <fluent-icon
          :icon="scheduleIcon"
          class="text-slate-500 dark:text-slate-400"
          size="14"
        />
        <span class="text-xs font-medium text-slate-700 dark:text-slate-300">
          {{ formattedDeadline }}
        </span>
      </div>
    </div>

    <!-- Informação da Conversa -->
    <div
      v-if="
        showConversationField &&
        !isItemCollapsed &&
        item.item_details?.conversation_id &&
        conversationData
      "
      class="flex items-center gap-2 mb-3 p-2 bg-slate-50 dark:bg-slate-800 rounded-lg border border-slate-100 dark:border-slate-700 min-h-[1.5rem] cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
      @click="navigateToConversation($event, item.item_details.conversation_id)"
      @contextmenu="
        handleContextMenu($event, item.item_details.conversation_id)
      "
    >
      <div class="flex items-center gap-2 flex-1">
        <fluent-icon
          icon="chat"
          class="text-slate-500 dark:text-slate-400 flex-shrink-0"
          size="16"
        />
        <div
          v-if="conversationData"
          class="flex items-center justify-between w-full"
        >
          <p class="text-xs text-slate-700 dark:text-slate-300 truncate my-0">
            #{{ conversationData.id }} - {{ truncatedSenderName }}
            <span
              class="ml-2 text-xs px-2 py-0.5 rounded-full"
              :class="{
                'bg-green-100 text-green-700':
                  conversationData.status === t('KANBAN.ITEM_STATUS.OPEN'),
                'bg-woot-110 text-yellow-700':
                  conversationData.status === t('KANBAN.ITEM_STATUS.PENDING'),
                'bg-slate-100 text-slate-700':
                  conversationData.status === t('KANBAN.ITEM_STATUS.RESOLVED'),
              }"
            >
              {{ conversationData.status }}
            </span>
          </p>
          <span
            v-if="conversationData.unread_count > 0"
            class="flex items-center justify-center h-4 min-w-[1rem] px-1 text-[0.625rem] font-medium bg-ruby-500 text-white rounded-full flex-shrink-0"
          >
            {{
              conversationData.unread_count > 9
                ? '9+'
                : conversationData.unread_count
            }}
          </span>
        </div>
        <div
          v-else-if="loadingConversation"
          class="text-xs text-slate-500 flex items-center"
        >
          {{ t('KANBAN.LOADING_CONVERSATION') }}
        </div>
        <div v-else class="text-xs text-slate-500 flex items-center">
          {{ t('KANBAN.CONVERSATION_NOT_FOUND') }}
        </div>
      </div>
    </div>

    <!-- Progress Bar do Checklist -->
    <div
      v-if="showChecklistField && !isItemCollapsed && totalItems > 0"
      class="flex items-center gap-2 mb-3"
    >
      <div class="flex-1">
        <div
          class="h-1.5 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden"
        >
          <div
            class="h-full bg-woot-500 transition-all duration-300 ease-out"
            :style="{ width: `${checklistProgress}%` }"
          />
        </div>
      </div>
      <span class="text-xs text-slate-500">
        {{ completedItems }}/{{ totalItems }}
      </span>
    </div>

    <div class="flex items-center justify-between">
      <div
        v-if="showAgentField && !isItemCollapsed"
        class="flex items-center gap-2"
      >
        <div class="flex items-center gap-2">
          <Avatar
            v-if="agentInfo"
            :name="agentInfo.name"
            :src="agentInfo.avatar_url"
            :size="24"
          />
          <span
            v-if="agentInfo"
            class="text-xs text-slate-600 dark:text-slate-400"
          >
            {{ agentInfo.name }}
          </span>
          <span v-else class="text-xs text-slate-400 dark:text-slate-600">
            {{ t('KANBAN.NO_AGENT_ASSIGNED') }}
          </span>
        </div>
      </div>

      <!-- Substituir a data pelos ícones -->
      <div
        v-if="showMetadataField"
        class="flex items-center gap-2 text-xs text-slate-500"
      >
        <div v-if="isItemCollapsed" class="flex items-center gap-1">
          <fluent-icon icon="arrow-outwards" size="12" />
        </div>
        <div v-if="timeInStage" class="flex items-center gap-1">
          <fluent-icon icon="calendar-clock" size="12" />
          {{ timeInStage }}
        </div>
        <div v-if="attachmentsCount > 0" class="flex items-center gap-1">
          <fluent-icon icon="attach" size="12" />
          {{ attachmentsCount }}
        </div>
        <div v-if="notesCount > 0" class="flex items-center gap-1">
          <fluent-icon icon="comment-add" size="12" />
          {{ notesCount }}
        </div>
      </div>
    </div>
  </div>

  <!-- Adicionar o ContextMenu -->
  <CustomContextMenu
    v-if="showContextMenu"
    :x="contextMenuPosition.x"
    :y="contextMenuPosition.y"
    :show="showContextMenu"
    @close="showContextMenu = false"
  >
    <div
      class="bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-1 w-[180px]"
    >
      <button
        class="w-full px-4 py-2 text-left text-sm hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200"
        @click.stop="handleQuickMessage"
        @mousedown.stop
        @mouseup.stop
      >
        <span class="flex items-center gap-2">
          <fluent-icon icon="chat" size="16" />
          {{ t('KANBAN.CONTEXT_MENU.QUICK_MESSAGE') }}
        </span>
      </button>
      <button
        class="w-full px-4 py-2 text-left text-sm hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200"
        @click="handleViewContact"
      >
        <span class="flex items-center gap-2">
          <fluent-icon icon="person" size="16" />
          {{ t('KANBAN.CONTEXT_MENU.VIEW_CONTACT') }}
        </span>
      </button>
    </div>
  </CustomContextMenu>

  <!-- Modal de Mensagem Rápida -->
  <Modal
    v-model:show="showSendMessageModal"
    :on-close="() => (showSendMessageModal = false)"
    :show-close-button="true"
    size="medium"
    :close-on-backdrop-click="false"
    :class="{ 'z-50': showSendMessageModal }"
  >
    <div class="settings-modal">
      <header class="settings-header">
        <h3 class="text-lg font-medium">
          {{ t('SEND_MESSAGE.TITLE') }}
        </h3>
      </header>

      <div class="settings-content">
        <SendMessageTemplate
          :conversation-id="item.item_details?.conversation_id"
          :current-stage="item.funnel_stage || ''"
          :contact="conversationData?.contact"
          :conversation="conversationData"
          :item="item"
          @close="
            () => {
              showSendMessageModal = false;
              showContextMenu.value = false;
            }
          "
          @send="
            data => {
              console.log('SendMessageTemplate @send');
              handleSendMessage(data);
            }
          "
        />
      </div>
    </div>
  </Modal>

  <!-- Modal de Confirmação de Exclusão -->
  <Modal
    v-model:show="showDeleteModal"
    :on-close="
      () => {
        showDeleteModal = false;
        itemToDelete = null;
      }
    "
  >
    <div class="p-6">
      <h3 class="text-lg font-medium mb-4">Confirmar exclusão</h3>
      <p class="text-sm text-slate-600 dark:text-slate-400 mb-6">
        Tem certeza que deseja excluir o item "{{ itemToDelete?.title }}"?
      </p>
      <div class="flex justify-end space-x-2">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="showDeleteModal = false"
        >
          Cancelar
        </woot-button>
        <woot-button
          variant="solid"
          color-scheme="alert"
          @click="confirmDelete"
        >
          Excluir
        </woot-button>
      </div>
    </div>
  </Modal>

  <!-- Modal de Status -->
  <Modal
    v-model:show="showStatusModal"
    :on-close="() => (showStatusModal = false)"
  >
    <div class="p-6">
      <h3 class="text-lg font-medium mb-4">Atualizar Status</h3>
      <div class="space-y-4">
        <div class="flex gap-2">
          <button
            class="flex-1 p-3 border rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800"
            :class="{
              'border-green-500 bg-green-50': statusForm.status === 'won',
            }"
            @click="statusForm.status = 'won'"
          >
            <span class="text-sm font-medium">Ganho</span>
          </button>
          <button
            class="flex-1 p-3 border rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800"
            :class="{
              'border-red-500 bg-red-50': statusForm.status === 'lost',
            }"
            @click="statusForm.status = 'lost'"
          >
            <span class="text-sm font-medium">Perdido</span>
          </button>
        </div>

        <div v-if="statusForm.status === 'lost'" class="space-y-2">
          <label class="text-sm font-medium">Motivo</label>
          <textarea
            v-model="statusForm.reason"
            class="w-full p-2 border rounded-lg"
            rows="3"
          />
        </div>

        <div class="flex justify-end gap-2">
          <woot-button variant="clear" @click="showStatusModal = false">
            Cancelar
          </woot-button>
          <woot-button variant="primary" @click="handleStatusSave">
            Salvar
          </woot-button>
        </div>
      </div>
    </div>
  </Modal>

  <!-- Modal de Visibilidade dos Campos -->
  <Modal
    v-model:show="showVisibilityModal"
    :on-close="() => (showVisibilityModal = false)"
    :show-close-button="true"
    size="medium"
  >
    <div class="settings-modal">
      <header class="settings-header">
        <h3 class="text-lg font-medium">
          {{ t('CONTEXT_MENU.CUSTOMIZE_FIELDS.TITLE') }}
        </h3>
      </header>
      <div class="settings-content">
        <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
          {{ t('CONTEXT_MENU.CUSTOMIZE_FIELDS.DESCRIPTION') }}
        </p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Coluna 1 -->
          <div class="space-y-4">
            <label
              class="flex items-center p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
            >
              <input
                type="checkbox"
                v-model="showDescriptionField"
                class="form-checkbox h-4 w-4 text-woot-500"
              />
              <span class="ml-2 text-sm">
                <span class="font-medium">{{ t('DESCRIPTION') }}</span>
                <span
                  class="inline-block ml-2 px-2.5 py-1 text-[10px] font-semibold bg-indigo-100 text-indigo-700 dark:bg-indigo-800 dark:text-indigo-100 rounded-md border border-indigo-200 dark:border-indigo-700 shadow-sm"
                  >{{
                    t('CONTEXT_MENU.CUSTOMIZE_FIELDS.VISIBLE_WHEN_COLLAPSED')
                  }}</span
                >
                <span class="block text-xs text-slate-500"
                  >Detalhes do card</span
                >
              </span>
            </label>

            <label
              class="flex items-center p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
            >
              <input
                type="checkbox"
                v-model="showLabelsField"
                class="form-checkbox h-4 w-4 text-woot-500"
              />
              <span class="ml-2 text-sm">
                <span class="font-medium">Etiquetas</span>
                <span class="block text-xs text-slate-500"
                  >Tags da conversa</span
                >
              </span>
            </label>

            <label
              class="flex items-center p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
            >
              <input
                type="checkbox"
                v-model="showPriorityField"
                class="form-checkbox h-4 w-4 text-woot-500"
              />
              <span class="ml-2 text-sm">
                <span class="font-medium">{{ t('KANBAN.FORM.LABEL') }}</span>
                <span class="block text-xs text-slate-500"
                  >{{ t('KANBAN.PRIORITY_LABELS.HIGH') }},
                  {{ t('KANBAN.PRIORITY_LABELS.MEDIUM') }},
                  {{ t('KANBAN.PRIORITY_LABELS.LOW') }}</span
                >
              </span>
            </label>

            <label
              class="flex items-center p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
            >
              <input
                type="checkbox"
                v-model="showValueField"
                class="form-checkbox h-4 w-4 text-woot-500"
              />
              <span class="ml-2 text-sm">
                <span class="font-medium">{{
                  t('KANBAN.FORM.VALUE.LABEL')
                }}</span>
                <span class="block text-xs text-slate-500">{{
                  t('KANBAN.FORM.VALUE.LABEL')
                }}</span>
              </span>
            </label>
          </div>

          <!-- Coluna 2 -->
          <div class="space-y-4">
            <label
              class="flex items-center p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
            >
              <input
                type="checkbox"
                v-model="showDeadlineField"
                class="form-checkbox h-4 w-4 text-woot-500"
              />
              <span class="ml-2 text-sm">
                <span class="font-medium">{{ t('KANBAN.DEADLINE') }}</span>
                <span class="block text-xs text-slate-500">{{
                  t('KANBAN.DEADLINE_DESCRIPTION')
                }}</span>
              </span>
            </label>

            <label
              class="flex items-center p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
            >
              <input
                type="checkbox"
                v-model="showConversationField"
                class="form-checkbox h-4 w-4 text-woot-500"
              />
              <span class="ml-2 text-sm">
                <span class="font-medium">{{
                  t('KANBAN.ITEM_CONVERSATION.TITLE')
                }}</span>
                <span class="block text-xs text-slate-500">{{
                  t('KANBAN.ITEM_CONVERSATION.DESCRIPTION')
                }}</span>
              </span>
            </label>

            <label
              class="flex items-center p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
            >
              <input
                type="checkbox"
                v-model="showChecklistField"
                class="form-checkbox h-4 w-4 text-woot-500"
              />
              <span class="ml-2 text-sm">
                <span class="font-medium">Checklist</span>
                <span class="block text-xs text-slate-500"
                  >Progresso das tarefas</span
                >
              </span>
            </label>

            <label
              class="flex items-center p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
            >
              <input
                type="checkbox"
                v-model="showAgentField"
                class="form-checkbox h-4 w-4 text-woot-500"
              />
              <span class="ml-2 text-sm">
                <span class="font-medium">Agente</span>
                <span class="block text-xs text-slate-500"
                  >Responsável atribuído</span
                >
              </span>
            </label>
          </div>
        </div>

        <div class="mt-4 pt-4 border-t border-slate-100 dark:border-slate-700">
          <label
            class="flex items-center p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
          >
            <input
              type="checkbox"
              v-model="showMetadataField"
              class="form-checkbox h-4 w-4 text-woot-500"
            />
            <span class="ml-2 text-sm">
              <span class="font-medium">Metadados</span>
              <span class="block text-xs text-slate-500"
                >Tempo na etapa, anexos e notas</span
              >
            </span>
          </label>
        </div>

        <div class="flex justify-between mt-6">
          <woot-button
            variant="clear"
            @click="
              () => {
                showDescriptionField = true;
                showLabelsField = true;
                showPriorityField = true;
                showValueField = true;
                showDeadlineField = true;
                showConversationField = true;
                showChecklistField = true;
                showAgentField = true;
                showMetadataField = true;
              }
            "
          >
            Restaurar padrão
          </woot-button>
          <woot-button variant="primary" @click="showVisibilityModal = false">
            Fechar
          </woot-button>
        </div>
      </div>
    </div>
  </Modal>
</template>

<style lang="scss" scoped>
.flex {
  &:first-child {
    margin-top: 0;
  }
}

.settings-modal {
  @apply flex flex-col;

  .settings-header {
    @apply p-4 border-b border-slate-100 dark:border-slate-700;
  }

  .settings-content {
    @apply p-4 space-y-4;
  }
}
</style>
