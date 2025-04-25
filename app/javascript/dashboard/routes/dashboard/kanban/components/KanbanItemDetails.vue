<script setup>
import { computed, ref, onMounted, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import PriorityIcon from 'dashboard/routes/dashboard/inbox/components/PriorityIcon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import agents from '../../../../api/agents';
import conversationAPI from '../../../../api/inbox/conversation';
import KanbanAPI from '../../../../api/kanban';
import contacts from '../../../../api/contacts';
import AttributeAPI from '../../../../api/attributes';
import { useStore } from 'vuex';
import { formatDistanceToNow, format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import FileUpload from 'vue-upload-component';
import { useFileUpload } from 'dashboard/composables/useFileUpload';
import { checkFileSizeLimit } from 'shared/helpers/FileHelper';
import {
  MAXIMUM_FILE_UPLOAD_SIZE,
  ALLOWED_FILE_TYPES,
} from 'shared/constants/messages';
import { emitter } from 'shared/helpers/mitt';
import { useRouter } from 'vue-router';
import CustomContextMenu from 'dashboard/components/ui/CustomContextMenu.vue';
import Modal from 'dashboard/components/Modal.vue';
import SendMessageTemplate from './SendMessageTemplate.vue';
import FunnelSelector from './FunnelSelector.vue';
import messageAPI from '../../../../api/inbox/message';

// Definição dos props e emits
const props = defineProps({
  item: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['update:item', 'close', 'edit', 'item-updated']);

const { t } = useI18n();
const store = useStore();
const router = useRouter();

// Refs para itens vinculados
const showItemSelector = ref(false);
const showConversationSelector = ref(false);
const showContactSelector = ref(false);
const kanbanItems = ref([]);
const conversations = ref([]);
const contactsList = ref([]);
const loadingItems = ref(false);
const loadingConversations = ref(false);
const loadingContacts = ref(false);
const selectedItemId = ref(null);
const selectedConversationId = ref(null);
const selectedContactId = ref(null);
const activeTab = ref('notes');

// Refs para o checklist
const newChecklistItem = ref('');
const hideCompletedItems = ref(false);

// Adicione estas refs para controle de edição
const editingChecklistItemId = ref(null);
const editingChecklistItemText = ref('');

// Adicione estas refs
const customAttributes = ref([]);
const loadingAttributes = ref(false);

// Computed properties
const checklistItems = ref(props.item.item_details?.checklist || []);

const filteredChecklistItems = computed(() => {
  if (hideCompletedItems.value) {
    return checklistItems.value.filter(item => !item.completed);
  }
  return checklistItems.value;
});

const totalItems = computed(() => checklistItems.value.length);
const completedItems = computed(
  () => checklistItems.value.filter(item => item.completed).length
);

const checklistProgress = computed(() => {
  if (totalItems.value === 0) return 0;
  return (completedItems.value / totalItems.value) * 100;
});

// Computed para obter o nome do estágio atual
const currentStageName = computed(() => {
  const currentFunnel = store.getters['funnel/getSelectedFunnel'];
  if (!currentFunnel?.stages || !props.item.funnel_stage) return '';

  return (
    currentFunnel.stages[props.item.funnel_stage]?.name ||
    props.item.funnel_stage
  );
});

// Adicione este computed para pegar o nome do usuário atual
const currentUser = computed(() => store.getters['getCurrentUser']);

// Adicione esta função para buscar os atributos disponíveis
const fetchCustomAttributes = async () => {
  try {
    loadingAttributes.value = true;
    const response = await AttributeAPI.getAttributesByModel();
    customAttributes.value = response.data.filter(
      attr => attr.attribute_model === 'conversation_attribute'
    );
  } catch (error) {
    console.error('Erro ao carregar atributos:', error);
  } finally {
    loadingAttributes.value = false;
  }
};

// Adicione este computed
const conversationAttributes = computed(() => {
  return props.item.item_details?.conversation?.custom_attributes || {};
});

// Função para buscar itens do kanban
const fetchKanbanItems = async () => {
  try {
    loadingItems.value = true;
    const response = await KanbanAPI.getItems();
    if (Array.isArray(response.data)) {
      kanbanItems.value = response.data.map(item => ({
        id: item.id,
        title: item.item_details?.title || t('KANBAN.UNTITLED_ITEM'),
        description: item.item_details?.description,
        value: item.item_details?.value,
        priority: item.item_details?.priority,
        stage: item.funnel_stage,
      }));
    }
  } catch (error) {
    console.error('Erro ao carregar itens:', error);
  } finally {
    loadingItems.value = false;
  }
};

const priorityInfo = computed(() => {
  // Buscar prioridade do item_details
  const priority = props.item.item_details?.priority?.toLowerCase() || 'none';

  // Se for none, retorna null para não exibir o badge
  if (priority === 'none') return null;

  const priorityMap = {
    high: {
      label: t('KANBAN.PRIORITY_LABELS.HIGH'),
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

const priorityClass = computed(() => {
  const priorityMap = {
    high: 'bg-ruby-50 dark:bg-ruby-800 text-ruby-800 dark:text-ruby-50',
    medium:
      'bg-yellow-50 dark:bg-woot-120 text-yellow-800 dark:text-yellow-50',
    low: 'bg-green-50 dark:bg-green-800 text-green-800 dark:text-green-50',
    none: 'bg-slate-50 dark:bg-slate-800 text-slate-800 dark:text-slate-50',
  };
  return (
    priorityMap[props.item.item_details?.priority?.toLowerCase() || 'none'] ||
    priorityMap.none
  );
});

const formattedValue = computed(() => {
  if (!props.item.item_details?.value) return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(props.item.item_details.value);
});

// Ref para armazenar os dados do usuário
const agentData = ref(null);
const loadingAgent = ref(false);

// Função para buscar dados do usuário
const fetchAgent = async agentId => {
  if (!agentId) return;

  try {
    loadingAgent.value = true;
    // Verificar se o usuário já está disponível no item
    if (props.item.item_details?.agent) {
      agentData.value = props.item.item_details.agent;
    } else {
      // Usar o store como fallback
      const storeAgents =
        store.getters['funnel/getSelectedFunnel']?.settings?.agents || [];
      agentData.value = storeAgents.find(agent => agent.id === agentId);
    }
  } catch (error) {
    console.error('Erro ao obter dados do agente:', error);
  } finally {
    loadingAgent.value = false;
  }
};

// Computed para formatar os dados do usuário
const agentInfo = computed(() => {
  if (!agentData.value) return null;

  return {
    name: agentData.value.name,
    avatar_url: agentData.value.thumbnail,
  };
});

// Ref para armazenar os dados da conversa
const conversationData = computed(() => {
  return props.item.item_details?.conversation || null;
});
const loadingConversation = ref(false);

// Função para buscar dados da conversa
const fetchConversationData = async conversationId => {
  if (!conversationId) return;

  try {
    loadingConversation.value = true;
    // Se a conversa já estiver nos detalhes do item, use-a
    if (props.item.item_details?.conversation) {
      conversationData.value = props.item.item_details.conversation;
    } else {
      // Fallback para API apenas se necessário
      const response = await conversationAPI.get({
        assigneeType: ['all'],
        status: ['open', 'pending', 'resolved'],
      });
      const conversations = response.data.data.payload;
      conversationData.value = conversations.find(c => c.id === conversationId);
    }
  } catch (error) {
    console.error('Erro ao carregar dados da conversa:', error);
  } finally {
    loadingConversation.value = false;
  }
};

// Refs para as notas
const currentNote = ref('');
const notes = ref([]);
const savingNotes = ref(false);
const editingNoteId = ref(null);
const editingNoteContent = ref('');

// Adicione estas refs para controle de anexos
const noteAttachments = ref([]);
const isUploadingAttachment = ref(false);

// Ref para armazenar o nome do arquivo selecionado
const selectedFileName = ref('');

// Função para verificar se é uma imagem
const isImage = attachment => {
  try {
    return !!(
      attachment &&
      typeof attachment === 'object' &&
      attachment.fileType &&
      typeof attachment.fileType === 'string' &&
      attachment.fileType.startsWith('image/')
    );
  } catch (error) {
    return false;
  }
};

// Funções auxiliares para lidar com anexos
const hasNonImageAttachments = note => {
  return note.attachments?.some(a => !isImage(a)) || false;
};

const hasImageAttachments = note => {
  return note.attachments?.some(isImage) || false;
};

const getNonImageAttachments = note => {
  return note.attachments?.filter(a => !isImage(a)) || [];
};

const getImageAttachments = note => {
  return note.attachments?.filter(isImage) || [];
};

const getFileIcon = attachment => {
  if (!attachment || !attachment.fileType) return '📎';
  return attachment.fileType.includes('pdf') ? '📄' : '📎';
};

// Adicione uma função auxiliar para registrar atividades
const registerActivity = async (type, details) => {
  try {
    const newActivity = {
      id: Date.now(),
      type,
      details,
      created_at: new Date().toISOString(),
      user: {
        id: currentUser.value.id,
        name: currentUser.value.name,
        avatar_url: currentUser.value.avatar_url,
      },
    };

    const activities = [
      ...(props.item.item_details?.activities || []),
      newActivity,
    ];

    const payload = {
      ...props.item,
      item_details: {
        ...props.item.item_details,
        activities,
      },
    };

    const { data } = await KanbanAPI.updateItem(props.item.id, payload);
    emit('update:item', data);
    emit('item-updated');
    props.item.item_details = data.item_details;
  } catch (error) {
    console.error('Erro ao registrar atividade:', error);
  }
};

// Modifique a função addNote para incluir os anexos
const addNote = async () => {
  if (!currentNote.value.trim() && !noteAttachments.value.length) return;

  try {
    savingNotes.value = true;

    if (editingNoteId.value) {
      // Atualiza a nota existente
      const updatedNotes = notes.value.map(note => {
        if (note.id === editingNoteId.value) {
          return {
            ...note,
            text: currentNote.value,
            attachments: [
              ...(note.attachments || []),
              ...noteAttachments.value,
            ],
            updated_at: new Date().toISOString(),
            author: currentUser.value.name,
            author_id: currentUser.value.id,
            author_avatar: currentUser.value.avatar_url,
          };
        }
        return note;
      });

      const payload = {
        ...props.item,
        item_details: {
          ...props.item.item_details,
          notes: updatedNotes,
        },
      };

      const { data } = await KanbanAPI.updateItem(props.item.id, payload);
      emit('update:item', data);
      emit('item-updated');
      notes.value = data.item_details.notes;
      props.item.item_details = data.item_details;

      // Registra a atividade de nota
      await registerActivity('note_added', {
        note_text: currentNote.value.substring(0, 100),
        has_attachments: noteAttachments.value.length > 0,
      });
    } else {
      // Adiciona nova nota
      const newNote = {
        id: Date.now(),
        text: currentNote.value,
        created_at: new Date().toISOString(),
        attachments: noteAttachments.value,
        author: currentUser.value.name,
        author_id: currentUser.value.id,
        author_avatar: currentUser.value.avatar_url,
      };

      const updatedNotes = [...(props.item.item_details?.notes || []), newNote];
      const payload = {
        ...props.item,
        item_details: {
          ...props.item.item_details,
          notes: updatedNotes,
        },
      };

      const { data } = await KanbanAPI.updateItem(props.item.id, payload);
      emit('update:item', data);
      emit('item-updated');
      notes.value = data.item_details.notes;
      props.item.item_details = data.item_details;

      // Registra a atividade de nota
      await registerActivity('note_added', {
        note_text: currentNote.value.substring(0, 100),
        has_attachments: noteAttachments.value.length > 0,
      });
    }

    // Limpa o estado
    currentNote.value = '';
    noteAttachments.value = [];
    selectedFileName.value = '';
    editingNoteId.value = null;
  } catch (error) {
    console.error('Erro ao adicionar nota:', error);
  } finally {
    savingNotes.value = false;
  }
};

// Watch para manter notes sincronizado com as mudanças do item
watch(
  () => props.item.item_details?.notes,
  newNotes => {
    if (newNotes) {
      notes.value = newNotes;
    }
  },
  { immediate: true }
);

// Função para buscar conversas
const fetchConversations = async () => {
  try {
    loadingConversations.value = true;
    const response = await conversationAPI.get({});

    conversations.value = response.data.data.payload.map(conversation => ({
      id: conversation.id,
      title:
        conversation.meta.sender.name ||
        conversation.meta.sender.email ||
        t('KANBAN.ITEM_CONVERSATION.NO_CONTACT'),
      description: conversation.messages[0]?.content || t('KANBAN.NO_MESSAGES'),
      unread_count: conversation.unread_count,
      created_at: new Date(conversation.created_at).toLocaleDateString(),
      channel_type: conversation.channel_type,
      status: conversation.status,
    }));
  } catch (error) {
    console.error('Erro ao carregar conversas:', error);
  } finally {
    loadingConversations.value = false;
  }
};

// Função para selecionar uma conversa
const selectConversation = conversation => {
  selectedConversationId.value = conversation.id;
  showConversationSelector.value = false;
};

// Função para buscar contatos
const fetchContacts = async () => {
  try {
    loadingContacts.value = true;
    const response = await contacts.get();
    contactsList.value = response.data?.payload || [];
  } catch (error) {
    console.error('Erro ao carregar contatos:', error);
  } finally {
    loadingContacts.value = false;
  }
};

// Função para selecionar um contato
const selectContact = contact => {
  selectedContactId.value = contact.id;
  showContactSelector.value = false;
};

// Função para buscar detalhes de um item vinculado
const getLinkedItemDetails = itemId => {
  return kanbanItems.value.find(item => item.id === itemId);
};

// Função para selecionar um item
const selectItem = item => {
  selectedItemId.value = item.id;
  showItemSelector.value = false;
};

// Função para buscar dados da conversa para uma nota
const fetchNoteConversationData = async conversationId => {
  if (!conversationId) return null;

  try {
    const response = await conversationAPI.get({});
    const conversations = response.data.data.payload;
    return conversations.find(c => c.id === conversationId);
  } catch (error) {
    console.error('Erro ao carregar conversa:', error);
    return null;
  }
};

// Função para buscar dados do contato para uma nota
const fetchNoteContactData = async contactId => {
  if (!contactId) return null;

  try {
    const response = await contacts.get();
    const contactsList = response.data?.payload;
    return contactsList.find(c => c.id === contactId);
  } catch (error) {
    console.error('Erro ao carregar contato:', error);
    return null;
  }
};

// Métodos para gerenciar o checklist
const addChecklistItem = async () => {
  if (!newChecklistItem.value.trim()) return;

  try {
    const newItem = {
      id: Date.now(),
      text: newChecklistItem.value.trim(),
      completed: false,
      created_at: new Date().toISOString(),
    };

    const updatedChecklist = [...checklistItems.value, newItem];

    const payload = {
      ...props.item,
      item_details: {
        ...props.item.item_details,
        checklist: updatedChecklist,
      },
    };

    const { data } = await KanbanAPI.updateItem(props.item.id, payload);
    checklistItems.value = data.item_details.checklist;
    props.item.item_details = data.item_details;

    // Registra a atividade de checklist
    await registerActivity('checklist_item_added', {
      item_text: newItem.text,
    });

    // Limpa o input
    newChecklistItem.value = '';
  } catch (error) {
    console.error('Erro ao adicionar item ao checklist:', error);
  }
};

const toggleChecklistItem = async item => {
  try {
    const updatedChecklist = checklistItems.value.map(i => ({
      ...i,
      completed: i.id === item.id ? !i.completed : i.completed,
    }));

    const payload = {
      account_id: props.item.account_id,
      funnel_id: props.item.funnel_id,
      funnel_stage: props.item.funnel_stage,
      position: props.item.position,
      custom_attributes: props.item.custom_attributes || {},
      item_details: {
        ...props.item.item_details,
        checklist: updatedChecklist,
      },
      timer_started_at: props.item.timer_started_at,
      timer_duration: props.item.timer_duration,
    };

    const { data } = await KanbanAPI.updateItem(props.item.id, payload);

    // Atualiza o estado local diretamente com a resposta da API
    checklistItems.value = data.item_details.checklist;
    props.item.item_details = data.item_details;

    // Ainda emite o evento para manter o componente pai atualizado
    emit('update:item', data);

    // Emitir evento de atualização
    emit('item-updated');

    // Registra a atividade de toggle do checklist
    await registerActivity('checklist_item_toggled', {
      item_text: item.text,
      completed: !item.completed,
    });
  } catch (error) {
    console.error('Erro ao atualizar item do checklist:', error);
  }
};

const deleteChecklist = async () => {
  try {
    const payload = {
      account_id: props.item.account_id,
      funnel_id: props.item.funnel_id,
      funnel_stage: props.item.funnel_stage,
      position: props.item.position,
      custom_attributes: props.item.custom_attributes || {},
      item_details: {
        ...props.item.item_details,
        checklist: [],
      },
      timer_started_at: props.item.timer_started_at,
      timer_duration: props.item.timer_duration,
    };

    const { data } = await KanbanAPI.updateItem(props.item.id, payload);

    // Atualiza o estado local diretamente com a resposta da API
    checklistItems.value = data.item_details.checklist || [];

    // Ainda emite o evento para manter o componente pai atualizado
    emit('update:item', data);

    // Emitir evento de atualização
    emit('item-updated');
  } catch (error) {
    console.error('Erro ao deletar checklist:', error);
  }
};

const removeChecklistItem = async itemToRemove => {
  try {
    // Remove o item do ref local
    const updatedChecklist = checklistItems.value.filter(
      item => item.id !== itemToRemove.id
    );

    // Atualiza o ref local
    checklistItems.value = updatedChecklist;

    // Prepara o payload com o item atualizado
    const payload = {
      ...props.item,
      item_details: {
        ...props.item.item_details,
        checklist: updatedChecklist,
      },
    };

    // Chama a API para atualizar
    const { data } = await KanbanAPI.updateItem(props.item.id, payload);

    // Emite o evento para atualizar o componente pai
    emit('update:item', data);

    // Emitir evento de atualização
    emit('item-updated');
  } catch (error) {
    // Em caso de erro, reverte a alteração local
    checklistItems.value = props.item.item_details?.checklist || [];
    console.error('Erro ao remover item do checklist:', error);
  }
};

const toggleItemSelector = () => {
  showItemSelector.value = !showItemSelector.value;
  if (showItemSelector.value) {
    showConversationSelector.value = false;
    showContactSelector.value = false;
  }
};

const toggleConversationSelector = () => {
  showConversationSelector.value = !showConversationSelector.value;
  if (showConversationSelector.value) {
    showItemSelector.value = false;
    showContactSelector.value = false;
  }
};

const toggleContactSelector = () => {
  showContactSelector.value = !showContactSelector.value;
  if (showContactSelector.value) {
    showItemSelector.value = false;
    showConversationSelector.value = false;
  }
};

const itemButtonText = computed(() => {
  if (showItemSelector.value) {
    return t('KANBAN.CANCEL');
  }

  if (selectedItemId.value) {
    const selectedItem = kanbanItems.value.find(
      item => item.id === selectedItemId.value
    );
    return selectedItem?.title || t('KANBAN.FORM.NOTES.LINK_ITEM');
  }

  return t('KANBAN.FORM.NOTES.LINK_ITEM');
});

const conversationButtonText = computed(() => {
  if (showConversationSelector.value) {
    return t('KANBAN.CANCEL');
  }

  if (selectedConversationId.value) {
    const selectedConversation = conversations.value.find(
      conv => conv.id === selectedConversationId.value
    );
    return selectedConversation
      ? `#${selectedConversation.id} - ${selectedConversation.title}`
      : t('KANBAN.FORM.NOTES.LINK_CONVERSATION');
  }

  return t('KANBAN.FORM.NOTES.LINK_CONVERSATION');
});

const contactButtonText = computed(() => {
  if (showContactSelector.value) {
    return t('KANBAN.CANCEL');
  }

  if (selectedContactId.value) {
    const selectedContact = contactsList.value.find(
      contact => contact.id === selectedContactId.value
    );
    return selectedContact?.name || t('KANBAN.FORM.NOTES.LINK_CONTACT');
  }

  return t('KANBAN.FORM.NOTES.LINK_CONTACT');
});

const checklistItemButtonText = computed(() => {
  if (showItemSelector.value) {
    return t('KANBAN.CANCEL');
  }

  if (selectedItemId.value) {
    const selectedItem = kanbanItems.value.find(
      item => item.id === selectedItemId.value
    );
    return selectedItem?.title || t('KANBAN.FORM.NOTES.LINK_ITEM');
  }

  return t('KANBAN.FORM.NOTES.LINK_ITEM');
});

// Adicione esta função de formatação
const formatStageDate = item => {
  if (!item || !item.stage_entered_at) return '';

  try {
    return t('KANBAN.STAGE.TIME_IN_STAGE', {
      time: formatDistanceToNow(new Date(item.stage_entered_at), {
        locale: ptBR,
        addSuffix: false,
      }),
    });
  } catch (error) {
    console.error('Erro ao calcular tempo na etapa:', error);
    return '';
  }
};

// Função para iniciar edição
const startEditChecklistItem = item => {
  editingChecklistItemId.value = item.id;
  editingChecklistItemText.value = item.text;
  newChecklistItem.value = item.text;
};

// Função para salvar edição
const saveEditedChecklistItem = async () => {
  try {
    const updatedChecklist = checklistItems.value.map(item => {
      if (item.id === editingChecklistItemId.value) {
        return { ...item, text: newChecklistItem.value };
      }
      return item;
    });

    // Prepara o payload com o item atualizado
    const payload = {
      ...props.item,
      item_details: {
        ...props.item.item_details,
        checklist: updatedChecklist,
      },
    };

    // Chama a API para atualizar
    const { data } = await KanbanAPI.updateItem(props.item.id, payload);

    // Atualiza o estado local
    checklistItems.value = updatedChecklist;

    // Limpa o estado de edição
    editingChecklistItemId.value = null;
    editingChecklistItemText.value = '';
    newChecklistItem.value = '';

    // Emite eventos de atualização
    emit('update:item', data);
    emit('item-updated');
  } catch (error) {
    console.error('Erro ao editar item do checklist:', error);
  }
};

// Função para cancelar edição
const cancelEditChecklistItem = () => {
  editingChecklistItemId.value = null;
  editingChecklistItemText.value = '';
  newChecklistItem.value = '';
};

// Modifique a função handleNoteAttachment para atualizar o nome do arquivo
const handleNoteAttachment = async file => {
  if (!file) return;

  // Atualiza o nome do arquivo selecionado
  selectedFileName.value = file.file.name;

  if (!props.item?.id) {
    console.error('ID do item não encontrado:', props.item);
    return;
  }

  isUploadingAttachment.value = true;
  try {
    if (checkFileSizeLimit(file, MAXIMUM_FILE_UPLOAD_SIZE)) {
      const formData = new FormData();
      formData.append('attachment', file.file);

      const url = `/api/v1/accounts/${store.getters.getCurrentAccountId}/kanban/items/${props.item.id}/note_attachments`;

      const response = await axios.post(url, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      const newAttachment = {
        id: response.data.id.toString(),
        url: response.data.attachment_url,
        filename: file.file.name,
        fileType: file.file.type || 'application/octet-stream',
        source: {
          type: 'note',
          id: Date.now(),
        },
      };

      // Adiciona o anexo à lista de anexos da nota atual
      noteAttachments.value = [...noteAttachments.value, newAttachment];
    }
  } catch (error) {
    console.error('Erro ao fazer upload:', error.message);
  } finally {
    isUploadingAttachment.value = false;
  }
};

const removeAttachment = async attachment => {
  const isItemAttachment = attachment.source.type === 'item';
  const url = isItemAttachment
    ? `/api/v1/accounts/${store.getters.getCurrentAccountId}/kanban/items/${props.item.id}/attachments/${attachment.id}`
    : `/api/v1/accounts/${store.getters.getCurrentAccountId}/kanban/items/${props.item.id}/note_attachments/${attachment.id}`;

  try {
    await axios.delete(url);

    if (isItemAttachment) {
      // Atualiza os anexos do item localmente
      const updatedAttachments = props.item.item_details.attachments.filter(
        a => a.id !== attachment.id
      );

      const payload = {
        ...props.item,
        item_details: {
          ...props.item.item_details,
          attachments: updatedAttachments,
        },
      };

      const { data } = await KanbanAPI.updateItem(props.item.id, payload);
      emit('update:item', data);
      emit('item-updated');
      // Atualiza o item_details com os novos dados
      props.item.item_details = data.item_details;
    } else {
      // Atualiza os anexos da nota
      const updatedNotes = notes.value.map(note => {
        if (note.id === attachment.source.id) {
          return {
            ...note,
            attachments: note.attachments.filter(a => a.id !== attachment.id),
          };
        }
        return note;
      });

      const payload = {
        ...props.item,
        item_details: {
          ...props.item.item_details,
          notes: updatedNotes,
        },
      };

      const { data } = await KanbanAPI.updateItem(props.item.id, payload);
      emit('update:item', data);
      emit('item-updated');
      notes.value = data.item_details.notes;
      // Atualiza o item_details com os novos dados
      props.item.item_details = data.item_details;
    }
  } catch (error) {
    console.error('Erro ao remover anexo:', error.message);
  }
};

// Adicione a função formatDate
const formatDate = date => {
  if (!date) return '';
  try {
    return format(new Date(date), 'dd/MM/yyyy HH:mm', { locale: ptBR });
  } catch (error) {
    console.error('Erro ao formatar data:', error);
    return '';
  }
};

// Computed para obter todos os anexos de todas as notas
const getAllAttachments = computed(() => {
  const noteAttachments = notes.value.reduce((attachments, note) => {
    if (note.attachments && Array.isArray(note.attachments)) {
      return [
        ...attachments,
        ...note.attachments.map(attachment => ({
          ...attachment,
          source: {
            type: 'note',
            id: note.id,
            date: note.created_at,
            text:
              note.text?.substring(0, 50) +
              (note.text?.length > 50 ? '...' : ''),
          },
        })),
      ];
    }
    return attachments;
  }, []);

  // Adiciona anexos do próprio item se existirem
  const itemAttachments =
    props.item.item_details?.attachments?.map(attachment => ({
      ...attachment,
      source: {
        type: 'item',
        id: props.item.id,
      },
    })) || [];

  return [...noteAttachments, ...itemAttachments];
});

onMounted(() => {
  fetchCustomAttributes();

  // Carregar dados do usuário se existir ID
  if (props.item.item_details?.agent_id) {
    fetchAgent(props.item.item_details.agent_id);
  }

  // Buscar contatos
  fetchContacts();

  // Inicializar dados locais
  if (props.item.item_details?.notes) {
    notes.value = props.item.item_details.notes;
  }

  if (props.item.item_details?.checklist) {
    checklistItems.value = props.item.item_details.checklist;
  }
});

onMounted(() => {
  // Inicializar dados locais primeiro
  if (props.item.item_details?.notes) {
    notes.value = props.item.item_details.notes;
  }

  if (props.item.item_details?.checklist) {
    checklistItems.value = props.item.item_details.checklist;
  }

  // Verificar se o usuário já está nos detalhes
  if (props.item.item_details?.agent) {
    agentData.value = props.item.item_details.agent;
    loadingAgent.value = false;
  } else if (props.item.item_details?.agent_id) {
    fetchAgent(props.item.item_details.agent_id);
  }

  // Verificar se a conversa já está nos detalhes
  if (props.item.item_details?.conversation) {
    conversationData.value = props.item.item_details.conversation;
    loadingConversation.value = false;
  } else if (props.item.item_details?.conversation_id) {
    fetchConversationData(props.item.item_details.conversation_id);
  }

  // Carregar atributos apenas se necessário
  if (
    props.item.item_details?.conversation_id &&
    activeTab.value === 'custom_fields'
  ) {
    fetchCustomAttributes();
  }

  // Evitar carregar todos os contatos se não for necessário
  if (activeTab.value === 'notes' && showContactSelector.value) {
    fetchContacts();
  }
});

onMounted(() => {
  // Inicializar dados locais
  if (props.item.item_details?.notes) {
    notes.value = props.item.item_details.notes;
  }

  if (props.item.item_details?.checklist) {
    checklistItems.value = props.item.item_details.checklist;
  }

  // Verificar se o usuário já está nos detalhes
  if (props.item.item_details?.agent) {
    agentData.value = props.item.item_details.agent;
    loadingAgent.value = false;
  } else if (props.item.item_details?.agent_id) {
    fetchAgent(props.item.item_details.agent_id);
  }

  // Verificar se a conversa já está nos detalhes
  if (props.item.item_details?.conversation) {
    conversationData.value = props.item.item_details.conversation;
    loadingConversation.value = false;
  } else if (props.item.item_details?.conversation_id) {
    fetchConversationData(props.item.item_details.conversation_id);
  }

  // Carregar atributos apenas se necessário
  if (
    props.item.item_details?.conversation_id &&
    activeTab.value === 'custom_fields'
  ) {
    fetchCustomAttributes();
  }

  // Evitar carregar todos os contatos se não for necessário
  if (activeTab.value === 'notes' && showContactSelector.value) {
    fetchContacts();
  }
});

// Adicionar watcher para carregar dados apenas quando necessário
watch(activeTab, newTab => {
  if (newTab === 'custom_fields' && customAttributes.value.length === 0) {
    fetchCustomAttributes();
  }

  if (
    newTab === 'notes' &&
    showContactSelector.value &&
    contactsList.value.length === 0
  ) {
    fetchContacts();
  }
});

// Função para remover uma nota
const removeNote = async noteId => {
  try {
    savingNotes.value = true;
    const updatedNotes = notes.value.filter(note => note.id !== noteId);

    const payload = {
      ...props.item,
      item_details: {
        ...props.item.item_details,
        notes: updatedNotes,
      },
    };

    const { data } = await KanbanAPI.updateItem(props.item.id, payload);
    emit('update:item', data);
    emit('item-updated');

    // Atualiza a ref notes com os dados mais recentes
    notes.value = data.item_details.notes;
  } catch (error) {
    console.error('Erro ao remover a nota:', error);
  } finally {
    savingNotes.value = false;
  }
};

const startEditNote = note => {
  editingNoteId.value = note.id;
  currentNote.value = note.text;
};

const cancelEditNote = () => {
  editingNoteId.value = null;
  currentNote.value = '';
  noteAttachments.value = [];
};

// Adicione a função para formatar o valor em BRL
const formatCurrency = value => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value);
};

// Adicione uma nova função para lidar com anexos do item
const handleItemAttachment = async file => {
  if (!file) return;

  if (!props.item?.id) {
    console.error('ID do item não encontrado:', props.item);
    return;
  }

  isUploadingAttachment.value = true;
  try {
    if (checkFileSizeLimit(file, MAXIMUM_FILE_UPLOAD_SIZE)) {
      const formData = new FormData();
      formData.append('attachment', file.file);

      const url = `/api/v1/accounts/${store.getters.getCurrentAccountId}/kanban/items/${props.item.id}/attachments`;

      const response = await axios.post(url, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      const newAttachment = {
        id: response.data.id.toString(),
        url: response.data.attachment_url,
        filename: file.file.name,
        fileType: file.file.type || 'application/octet-stream',
        source: {
          type: 'item',
          id: props.item.id,
        },
      };

      // Atualiza os anexos do item
      const updatedAttachments = [
        ...(props.item.item_details.attachments || []),
        newAttachment,
      ];

      const payload = {
        ...props.item,
        item_details: {
          ...props.item.item_details,
          attachments: updatedAttachments,
        },
      };

      const { data } = await KanbanAPI.updateItem(props.item.id, payload);
      emit('update:item', data);
      emit('item-updated');
      props.item.item_details = data.item_details;

      // Registra a atividade de upload
      await registerActivity('attachment_added', {
        filename: file.file.name,
        file_type: file.file.type,
      });
    }
  } catch (error) {
    console.error('Erro ao fazer upload:', error.message);
  } finally {
    isUploadingAttachment.value = false;
  }
};

const history = computed(() => {
  console.log('Histórico: item_details', props.item.item_details);
  const activities = props.item.item_details?.activities || [];
  console.log('Atividades encontradas:', activities.length);

  return activities
    .map(activity => {
      console.log('Processando atividade:', activity.type, activity);
      let icon, title, details;

      switch (activity.type) {
        case 'attachment_added':
          icon = 'attach';
          title = t('KANBAN.HISTORY.ATTACHMENT_ADDED');
          details = `${t('KANBAN.HISTORY.FILE')}: ${activity.details.filename}`;
          break;

        case 'note_added':
          icon = 'comment-add';
          title = t('KANBAN.HISTORY.NOTE_ADDED');
          details = activity.details.note_text;
          break;

        case 'checklist_item_added':
          icon = 'add-circle';
          title = t('KANBAN.HISTORY.CHECKLIST_ITEM_ADDED');
          details = activity.details.item_text;
          break;

        case 'checklist_item_toggled':
          icon = activity.details.completed ? 'checkmark' : 'dismiss';
          title = t('KANBAN.HISTORY.CHECKLIST_ITEM_UPDATED');
          details = `${activity.details.item_text} - ${
            activity.details.completed
              ? t('KANBAN.HISTORY.COMPLETED')
              : t('KANBAN.HISTORY.PENDING')
          }`;
          break;

        case 'priority_changed':
          icon = 'alert';
          title = t('KANBAN.HISTORY.PRIORITY_CHANGED');
          details = `${activity.details.old_priority || t('KANBAN.HISTORY.NONE')} → ${activity.details.new_priority}`;
          break;

        case 'status_changed':
          icon = 'status';
          title = t('KANBAN.HISTORY.STATUS_CHANGED');
          details = `${activity.details.old_status || t('KANBAN.HISTORY.PENDING')} → ${activity.details.new_status}`;
          break;

        case 'stage_changed':
          icon = 'arrow-right';
          title = t('KANBAN.HISTORY.STAGE_CHANGED');
          details = `${activity.details.old_stage || '-'} → ${activity.details.new_stage}`;
          break;

        case 'value_changed':
          icon = 'credit-card-person';
          title = t('KANBAN.HISTORY.VALUE_CHANGED');
          const oldValue = activity.details.old_value || '0';
          const newValue = activity.details.new_value;
          const currency = activity.details.currency?.symbol || 'R$';
          details = `${currency} ${oldValue} → ${currency} ${newValue}`;
          break;

        case 'agent_changed':
          icon = 'person';
          title = t('KANBAN.HISTORY.AGENT_CHANGED');
          details = `${activity.details.old_agent || t('KANBAN.HISTORY.NONE')} → ${activity.details.new_agent || t('KANBAN.HISTORY.NONE')}`;
          break;

        case 'conversation_linked':
          icon = 'chat';
          title = t('KANBAN.HISTORY.CONVERSATION_LINKED');
          details = `${activity.details.user?.name || t('KANBAN.SYSTEM')} ${t('KANBAN.HISTORY.LINKED_CONVERSATION')} #${activity.details.conversation_id} - ${activity.details.conversation_title}`;
          break;

        default:
          icon = 'info';
          title = `${t('KANBAN.HISTORY.ACTIVITY')}: ${activity.type}`;
          details = JSON.stringify(activity.details);
      }

      return {
        ...activity,
        icon,
        title,
        details,
      };
    })
    .reverse();
});

// Add to handleUpdateNotes or similar update function
const handleUpdateNotes = async () => {
  try {
    isUpdating.value = true;
    await KanbanAPI.updateNotes(props.item.id, notes.value);

    emitter.emit('newToastMessage', {
      message: t('KANBAN.NOTES_UPDATED_SUCCESSFULLY'),
      action: { type: 'success' },
    });
  } catch (error) {
    emitter.emit('newToastMessage', {
      message: t('KANBAN.ERROR_UPDATING_NOTES'),
      action: { type: 'error' },
    });
  } finally {
    isUpdating.value = false;
  }
};

// No método handleChecklistUpdate
const handleChecklistUpdate = async () => {
  try {
    isUpdating.value = true;
    await KanbanAPI.updateChecklist(props.item.id, checklistItems.value);

    emitter.emit('newToastMessage', {
      message: t('KANBAN.CHECKLIST_UPDATED_SUCCESSFULLY'),
      action: { type: 'success' },
    });
  } catch (error) {
    emitter.emit('newToastMessage', {
      message: t('KANBAN.ERROR_UPDATING_CHECKLIST'),
      action: { type: 'error' },
    });
  } finally {
    isUpdating.value = false;
  }
};

// Adicione uma função para navegar para uma conversa
const navigateToConversation = (e, conversationId) => {
  e.stopPropagation();
  if (!conversationId) return;

  // Obter o account_id de forma mais segura
  const accountId = store.getters.getCurrentAccountId;

  try {
    router.push({
      name: 'inbox_conversation_through_inbox',
      params: {
        accountId,
        conversationId,
      },
    });
  } catch (error) {
    console.error('Erro ao navegar para a conversa:', error);
    // Fallback: navegação direta pela URL com account_id atual
    window.location.href = `/app/accounts/${accountId}/conversations/${conversationId}`;
  }
};

// Adicione uma função para lidar com o contexto do menu
const handleContextMenu = (e, conversationId) => {
  if (!conversationId || !conversationData.value) return;

  e.preventDefault();
  showContextMenu.value = true;
  contextMenuPosition.value = {
    x: e.clientX,
    y: e.clientY,
  };
};

const showContextMenu = ref(false);
const contextMenuPosition = ref({ x: 0, y: 0 });
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

  console.log('Dados do item:', props.item);
  console.log('Dados da conversa:', props.item.item_details?.conversation);

  // Verifica se temos os dados necessários
  if (!props.item.item_details?.conversation?.id) {
    console.log('ID da conversa não encontrado');
    return;
  }

  const accountId = store.getters.getCurrentAccountId;
  const conversationId = props.item.item_details.conversation.id;

  console.log('Navegando para conversa:', {
    accountId,
    conversationId,
    route: 'inbox_conversation_through_inbox',
  });

  try {
    // Navega para a conversa usando a mesma rota do card
    router.push({
      name: 'inbox_conversation_through_inbox',
      params: {
        accountId,
        conversationId,
      },
    });
  } catch (err) {
    console.error('Erro na navegação:', err);
    // Fallback: navegação direta pela URL
    window.location.href = `/app/accounts/${accountId}/conversations/${conversationId}`;
  }
};

// Adicione este watch
watch(showSendMessageModal, newValue => {
  if (!newValue) {
    nextTick(() => {
      showContextMenu.value = false;
    });
  }
});

// Adicione ao script
const tabs = [
  { id: 'notes', icon: 'document', label: t('KANBAN.TABS.NOTES') },
  {
    id: 'checklist',
    icon: 'checkmark-circle',
    label: t('KANBAN.TABS.CHECKLIST'),
  },
  { id: 'attachments', icon: 'attach', label: t('KANBAN.TABS.ATTACHMENTS') },
  { id: 'history', icon: 'calendar-clock', label: t('KANBAN.TABS.HISTORY') },
  { id: 'custom_fields', icon: 'edit', label: t('KANBAN.TABS.CUSTOM_FIELDS') },
];

// Adicione este computed
const truncatedConversationTitle = computed(() => {
  const title =
    conversationData.value?.contact?.name ||
    conversationData.value?.contact?.email ||
    '';
  return title.length > 17 ? `${title.substring(0, 10)}...` : title;
});

// Adicione estes computed properties
const conversationLabels = computed(() => {
  return props.item.item_details?.conversation?.labels || [];
});

const channelType = computed(() => {
  const channel = props.item.item_details?.conversation?.meta?.channel;
  return channel?.replace('Channel::', '') || '';
});

const lastMessage = computed(() => {
  return props.item.item_details?.conversation?.last_non_activity_message;
});

const lastActivity = computed(() => {
  const timestamp = props.item.item_details?.conversation?.last_activity_at;
  if (!timestamp) return '';

  try {
    // Verificar se o timestamp é válido
    const date = new Date(Number(timestamp) * 1000);
    if (isNaN(date.getTime())) {
      return ''; // Retorna string vazia se a data for inválida
    }

    return formatDistanceToNow(date, {
      addSuffix: true,
      locale: ptBR,
    });
  } catch (error) {
    console.error('Erro ao formatar data:', error);
    return ''; // Fallback seguro
  }
});

// Adicionar truncatedSenderName
const truncatedSenderName = computed(() => {
  const name = conversationData.value?.contact?.name;
  const email = conversationData.value?.contact?.email;
  const defaultText = t('KANBAN.ITEM_CONVERSATION.NO_CONTACT');
  const text = name || email || defaultText;

  return text.length > 10 ? `${text.substring(0, 10)}...` : text;
});

// Template para o card da conversa
const showDebug = ref(false);

onMounted(() => {
  console.log('KanbanItemDetails montado com item:', props.item);
  console.log('Item details:', props.item.item_details);
  if (props.item.item_details?.activities) {
    console.log('Atividades:', props.item.item_details?.activities.length);
  }
});

// Adicione este computed para lidar com a descrição
const itemDescription = computed(() => {
  return props.item.item_details?.description || props.item.description || '';
});

// Dados para ações rápidas
const quickActions = [
  { id: 'move', icon: 'arrow-right', color: 'emerald' },
  { id: 'assign', icon: 'person', color: 'violet' },
  { id: 'chat', icon: 'chat', color: 'amber' },
  { id: 'duplicate', icon: 'copy', color: 'sky' },
];

const newMessage = ref('');

// Função para enviar mensagem (mock)
const sendMessage = async text => {
  try {
    const payload = {
      content: text.target.value,
      private: false,
      echo_id: Date.now().toString(),
      cc_emails: '',
      bcc_emails: '',
      to_emails: '',
    };

    const { data } = await messageAPI.create({
      conversationId: props.item.item_details.conversation.id,
      message: payload.content,
      private: payload.private,
      echo_id: payload.echo_id,
      cc_emails: payload.cc_emails,
      bcc_emails: payload.bcc_emails,
      to_emails: payload.to_emails,
    });

    messages.value.push({
      id: data.id,
      text: payload.content,
      isMe: true,
      timestamp: new Date().toISOString(),
    });

    nextTick(() => {
      scrollToBottom();
    });
    await loadMessages();
  } catch (error) {
    console.error('Error sending message:', error);
  }
};

// Função para lidar com ações rápidas
const handleQuickAction = actionId => {
  switch (actionId) {
    case 'move':
      showMoveModal.value = true;
      break;
    case 'assign':
      console.log('=== Debug Navegação ===');
      const accountId = store.getters.getCurrentAccountId;
      const contactId = props.item.item_details?.conversation?.contact?.id;

      if (!contactId) {
        console.log('ID do contato não encontrado');
        return;
      }

      const routeConfig = {
        name: 'contacts_show',
        params: {
          accountId,
          id: contactId,
        },
      };
      console.log('Route Config:', routeConfig);

      try {
        console.log('Tentando navegar via router.push...');
        router.push(routeConfig);
      } catch (err) {
        console.error('Erro na navegação:', err);
        const fallbackUrl = `/app/accounts/${accountId}/contacts/${contactId}`;
        console.log('Usando fallback URL:', fallbackUrl);
        window.location.href = fallbackUrl;
      }
      break;
    case 'chat':
      showSendMessageModal.value = true;
      break;
    case 'duplicate':
      handleDuplicateItem();
      break;
    default:
      break;
  }
};

// Adicione antes do setup
const showMoveModal = ref(false);
const moveForm = ref({
  funnel_id: props.item.funnel_id,
  funnel_stage: props.item.funnel_stage,
});

// Computed para obter as etapas do funil selecionado
const availableStages = computed(() => {
  const selectedFunnel = store.getters['funnel/getSelectedFunnel'];
  if (!selectedFunnel?.stages) return [];

  return Object.entries(selectedFunnel.stages)
    .map(([id, stage]) => ({
      id,
      name: stage.name,
      position: stage.position,
    }))
    .sort((a, b) => a.position - b.position);
});

// Função para mover o item
const handleMove = async () => {
  try {
    const payload = {
      ...props.item,
      funnel_id: moveForm.value.funnel_id,
      funnel_stage: moveForm.value.funnel_stage,
    };

    const { data } = await KanbanAPI.updateItem(props.item.id, payload);
    emit('update:item', data);
    showMoveModal.value = false;

    // Registra a atividade
    await registerActivity('stage_changed', {
      old_stage: props.item.funnel_stage,
      new_stage: moveForm.value.funnel_stage,
    });
  } catch (error) {
    console.error('Erro ao mover item:', error);
  }
};

// Função para duplicar o item
const handleDuplicateItem = async () => {
  try {
    const duplicatedItem = {
      ...props.item,
      id: undefined,
      item_details: {
        ...props.item.item_details,
        title: `${props.item.item_details.title} (Cópia)`,
      },
    };

    const { data } = await KanbanAPI.createItem(duplicatedItem);
    emitter.emit('newToastMessage', {
      message: 'Item duplicado com sucesso',
      action: { type: 'success' },
    });
  } catch (error) {
    emitter.emit('newToastMessage', {
      message: 'Erro ao duplicar o item',
      action: { type: 'error' },
    });
  }
};

// Remove mockMessages
const messages = ref([]);
const isLoadingMessages = ref(false);

const loadMessages = async () => {
  const accountId = store.getters.getCurrentAccountId;
  if (!props.item.item_details?.conversation?.id || !accountId) {
    console.log('No conversation ID or account ID found');
    return;
  }

  try {
    isLoadingMessages.value = true;
    const response = await messageAPI.getPreviousMessages({
      accountId,
      conversationId: props.item.item_details.conversation.id,
      before: Math.floor(Date.now() / 1000),
    });

    messages.value = response.data.payload
      .filter(msg => msg.message_type === 1)
      .map(msg => ({
        id: msg.id,
        text: msg.content,
        isMe: msg.sender?.id === currentUser.value?.id,
        timestamp: new Date(Number(msg.created_at) * 1000).toLocaleTimeString(
          'pt-BR',
          {
            hour: '2-digit',
            minute: '2-digit',
          }
        ),
        sender: msg.sender,
      }));

    nextTick(() => {
      scrollToBottom();
    });
  } catch (error) {
    console.error('Error loading messages:', error);
  } finally {
    isLoadingMessages.value = false;
  }
};

const scrollToBottom = () => {
  const chatContainer = document.querySelector('.chat-messages');
  if (chatContainer) {
    chatContainer.scrollTop = chatContainer.scrollHeight;
  }
};

// Adiciona watch para recarregar mensagens quando a conversa mudar
watch(
  () => props.item.item_details?.conversation?.id,
  newId => {
    console.log('Conversation ID changed:', newId);
    if (newId) {
      loadMessages();
    }
  }
);

// Garante que as mensagens sejam carregadas quando o componente for montado
onMounted(() => {
  console.log('Component mounted, loading messages...');
  loadMessages();
});
</script>

<template>
  <div class="kanban-details flex gap-4">
    <!-- Bloco Esquerdo (Existente) -->
    <div class="w-2/3 p-8 space-y-6">
      <!-- Cabeçalho -->
      <div class="header-section">
        <div class="flex items-center justify-between gap-4 mb-3">
          <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-100">
            {{ props.item.item_details.title }}
          </h3>
          <div class="flex items-center gap-2">
            <PriorityIcon
              :priority="props.item.item_details?.priority || 'none'"
            />
            <span
              v-if="
                props.item.item_details?.priority &&
                props.item.item_details.priority !== 'none'
              "
              class="px-3 py-1.5 text-sm font-medium rounded-full"
              :class="priorityClass"
            >
              {{
                priorityInfo?.label ||
                t(
                  `KANBAN.PRIORITY_LABELS.${(props.item.item_details?.priority || 'NONE').toUpperCase()}`
                )
              }}
            </span>
            <span
              v-else
              class="px-3 py-1.5 text-sm font-medium rounded-full bg-slate-50 dark:bg-slate-800 text-slate-800 dark:text-slate-50"
            >
              {{ t('KANBAN.PRIORITY_LABELS.NONE') }}
            </span>
          </div>
        </div>
        <p
          v-if="itemDescription"
          class="text-base text-slate-600 dark:text-slate-400 mb-4"
        >
          {{ itemDescription }}
        </p>

        <!-- Grid de informações principais -->
        <div class="info-grid">
          <!-- Usuário Responsável -->
          <div class="info-card">
            <span class="info-label">
              {{ t('KANBAN.ITEM_DETAILS.AGENT_RESPONSIBLE') }}
            </span>
            <div class="info-content">
              <div v-if="loadingAgent" class="loading-text">
                {{ t('KANBAN.ITEM_DETAILS.LOADING_AGENT') }}
              </div>
              <div v-else-if="agentInfo" class="flex items-center gap-2">
                <Avatar
                  :name="agentInfo.name"
                  :src="agentInfo.avatar_url"
                  :size="28"
                />
                <span class="font-medium">{{ agentInfo.name }}</span>
              </div>
              <div v-else class="no-data-text">
                {{ t('KANBAN.ITEM_DETAILS.NO_AGENT') }}
              </div>
            </div>
          </div>

          <!-- Conversa Relacionada -->
          <div
            v-if="props.item.item_details?.conversation_id"
            class="info-card"
          >
            <span class="info-label">
              {{ t('KANBAN.FORM.CONVERSATION.LABEL') }}
            </span>
            <div
              class="flex items-center gap-2 p-2 bg-slate-50 dark:bg-slate-800 rounded-lg border border-slate-100 dark:border-slate-700 min-h-[1.5rem] cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
              @click="
                navigateToConversation(
                  $event,
                  props.item.item_details.conversation_id
                )
              "
              @contextmenu="
                handleContextMenu(
                  $event,
                  props.item.item_details.conversation_id
                )
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
                  <div
                    class="text-xs text-slate-700 dark:text-slate-300 truncate my-0"
                  >
                    #{{ conversationData.id }} - {{ truncatedSenderName }}
                    <span
                      class="ml-2 text-xs px-2 py-0.5 rounded-full"
                      :class="{
                        'bg-green-100 text-green-700':
                          conversationData.status === 'open',
                        'bg-woot-110 text-yellow-700':
                          conversationData.status === 'pending',
                        'bg-slate-100 text-slate-700':
                          conversationData.status === 'resolved',
                      }"
                    >
                      {{ conversationData.status }}
                    </span>
                  </div>
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
          </div>

          <!-- Valor Negociado -->
          <div v-if="formattedValue" class="info-card">
            <span class="info-label">
              {{ t('KANBAN.FORM.VALUE.LABEL') }}
            </span>
            <span class="info-content value-text">
              {{ formattedValue }}
            </span>
          </div>

          <!-- Etapa Atual -->
          <div class="info-card">
            <span class="info-label">
              {{ t('KANBAN.FORM.STAGE.LABEL') }}
            </span>
            <div class="info-content flex items-center gap-2">
              <span class="font-medium">
                {{ currentStageName }}
              </span>
              <span class="text-xs text-slate-500">
                {{ formatStageDate(item) }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="space-y-4">
        <!-- Tabs -->
        <div class="flex border-b border-slate-200 dark:border-slate-700 mb-6">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            class="tab-button"
            :class="activeTab === tab.id ? 'tab-active' : 'tab-inactive'"
            @click="activeTab = tab.id"
          >
            <div class="flex items-center gap-2">
              <fluent-icon :icon="tab.icon" size="16" />
              {{ tab.label }}
            </div>
          </button>
        </div>

        <!-- Conteúdo das Tabs -->
        <div class="space-y-6">
          <!-- Tab de Notas -->
          <div v-if="activeTab === 'notes'" class="space-y-4">
            <!-- Campo de texto para nova nota -->
            <div class="note-input-section">
              <textarea
                v-model="currentNote"
                class="w-full px-3 py-2 text-sm border border-slate-200 bg-slate-50 rounded-lg focus:ring-1 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-800 dark:border-slate-700 dark:text-slate-300 resize-none"
                :placeholder="t('KANBAN.FORM.NOTES.PLACEHOLDER')"
                rows="3"
              />

              <!-- Botões de ação -->
              <div class="flex flex-col gap-2 mt-2">
                <!-- Grupo de botões de vinculação e anexo -->
                <div class="flex items-center gap-2">
                  <!-- Botão de anexo -->
                  <FileUpload
                    ref="upload"
                    :accept="ALLOWED_FILE_TYPES"
                    @input-file="handleNoteAttachment"
                  >
                    <button
                      class="action-button hover:bg-slate-100 dark:hover:bg-slate-600"
                      :disabled="isUploadingAttachment"
                    >
                      <fluent-icon icon="attach" size="20" />
                      <span v-if="isUploadingAttachment">...</span>
                    </button>
                  </FileUpload>

                  <!-- Botões existentes -->
                  <button
                    class="action-button"
                    @click="showItemSelector = true"
                  >
                    <fluent-icon icon="link" size="20" />
                  </button>
                  <button
                    class="action-button"
                    @click="showConversationSelector = true"
                  >
                    <fluent-icon icon="chat" size="20" />
                  </button>
                  <button
                    class="action-button"
                    @click="showContactSelector = true"
                  >
                    <fluent-icon icon="person" size="20" />
                  </button>
                </div>

                <!-- Preview do arquivo selecionado -->
                <div
                  v-if="selectedFileName"
                  class="flex items-center gap-2 px-2 py-1 text-xs text-slate-600 dark:text-slate-400"
                >
                  <fluent-icon icon="document" size="12" />
                  <span class="truncate">{{ selectedFileName }}</span>
                </div>
              </div>

              <!-- Botão de adicionar nota -->
              <button
                class="primary-button"
                :disabled="!currentNote.trim()"
                @click="addNote"
              >
                {{ t('KANBAN.ADD') }}
              </button>
            </div>

            <!-- Seletor de itens -->
            <div
              v-if="showItemSelector"
              class="absolute z-50 left-8 right-8 mt-2 bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 shadow-lg"
            >
              <div
                class="px-4 py-3 border-b border-slate-200 dark:border-slate-700"
              >
                <h4
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ t('KANBAN.FORM.NOTES.SELECT_ITEM') }}
                </h4>
              </div>

              <div class="max-h-[280px] overflow-y-auto custom-scrollbar">
                <div
                  v-if="loadingItems"
                  class="p-4 text-center text-sm text-slate-500"
                >
                  <span class="loading-spinner w-4 h-4 mr-2" />
                  {{ t('KANBAN.LOADING') }}
                </div>

                <div
                  v-else-if="kanbanItems.length === 0"
                  class="p-4 text-center"
                >
                  <p class="text-sm text-slate-500">
                    {{ t('KANBAN.FORM.NOTES.NO_ITEMS') }}
                  </p>
                </div>

                <div
                  v-else
                  class="divide-y divide-slate-100 dark:divide-slate-700"
                >
                  <button
                    v-for="item in kanbanItems"
                    :key="item.id"
                    class="w-full px-4 py-3 text-left hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-700"
                    @click="selectItem(item)"
                  >
                    <div class="flex items-center gap-3">
                      <!-- Prioridade -->
                      <div
                        class="flex-shrink-0 w-1.5 h-5 rounded-full"
                        :class="{
                          'bg-ruby-500': item.priority === 'high',
                          'bg-yellow-500': item.priority === 'medium',
                          'bg-green-500': item.priority === 'low',
                          'bg-slate-300': item.priority === 'none',
                        }"
                      />

                      <div class="flex items-center gap-3 flex-1 min-w-0">
                        <!-- Título -->
                        <h4
                          class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate flex-1"
                        >
                          {{ item.title }}
                        </h4>

                        <!-- Etapa -->
                        <span
                          class="px-2 py-0.5 text-xs font-medium rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 whitespace-nowrap"
                        >
                          {{ item.stage_name }}
                        </span>

                        <!-- Data -->
                        <span
                          class="flex items-center gap-1 text-xs text-slate-400 whitespace-nowrap"
                        >
                          <fluent-icon icon="calendar" size="12" />
                          {{ item.createdAt }}
                        </span>
                      </div>
                    </div>
                    <!-- Descrição -->
                    <p
                      v-if="item.description"
                      class="mt-1 ml-6 text-xs text-slate-500 dark:text-slate-400 line-clamp-1"
                    >
                      {{ item.description }}
                    </p>
                  </button>
                </div>
              </div>
            </div>

            <!-- Seletor de conversas -->
            <div
              v-if="showConversationSelector"
              class="absolute z-50 left-8 right-8 mt-2 bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 shadow-lg"
            >
              <div
                class="px-4 py-3 border-b border-slate-200 dark:border-slate-700"
              >
                <h4
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ t('KANBAN.FORM.NOTES.SELECT_CONVERSATION') }}
                </h4>
              </div>

              <div class="max-h-[280px] overflow-y-auto custom-scrollbar">
                <div
                  v-if="loadingConversations"
                  class="p-4 text-center text-sm text-slate-500"
                >
                  <span class="loading-spinner w-4 h-4 mr-2" />
                  {{ t('KANBAN.LOADING') }}
                </div>

                <div
                  v-else-if="conversations.length === 0"
                  class="p-4 text-center"
                >
                  <p class="text-sm text-slate-500">
                    {{ t('KANBAN.FORM.NOTES.NO_CONVERSATIONS') }}
                  </p>
                </div>

                <div
                  v-else
                  class="divide-y divide-slate-100 dark:divide-slate-700"
                >
                  <button
                    v-for="conversation in conversations"
                    :key="conversation.id"
                    class="w-full px-4 py-3 text-left hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-700"
                    @click="selectConversation(conversation)"
                  >
                    <div class="flex items-center gap-3">
                      <!-- Status -->
                      <div
                        class="flex-shrink-0 w-1.5 h-5 rounded-full"
                        :class="{
                          'bg-green-500': conversation.status === 'open',
                          'bg-yellow-500': conversation.status === 'pending',
                          'bg-slate-500': conversation.status === 'resolved',
                        }"
                      />

                      <div class="flex items-center gap-3 flex-1 min-w-0">
                        <!-- ID e Título -->
                        <h4
                          class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate flex-1"
                        >
                          #{{ conversation.id }} - {{ conversation.title }}
                        </h4>

                        <!-- Canal -->
                        <span
                          class="px-2 py-0.5 text-xs font-medium rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 whitespace-nowrap"
                        >
                          {{ conversation.channel_type }}
                        </span>

                        <!-- Data -->
                        <span
                          class="flex items-center gap-1 text-xs text-slate-400 whitespace-nowrap"
                        >
                          <fluent-icon icon="contact-card" size="12" />
                          {{ conversation.created_at }}
                        </span>
                      </div>
                    </div>
                    <!-- Última mensagem -->
                    <p
                      v-if="conversation.description"
                      class="mt-1 ml-6 text-xs text-slate-500 dark:text-slate-400 line-clamp-1"
                    >
                      {{ conversation.description }}
                    </p>
                  </button>
                </div>
              </div>
            </div>

            <!-- Seletor de contatos -->
            <div
              v-if="showContactSelector"
              class="absolute z-50 left-8 right-8 mt-2 bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 shadow-lg"
            >
              <div
                class="px-4 py-3 border-b border-slate-200 dark:border-slate-700"
              >
                <h4
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ t('KANBAN.FORM.NOTES.SELECT_CONTACT') }}
                </h4>
              </div>

              <div class="max-h-[280px] overflow-y-auto custom-scrollbar">
                <div
                  v-if="loadingContacts"
                  class="p-4 text-center text-sm text-slate-500"
                >
                  <span class="loading-spinner w-4 h-4 mr-2" />
                  {{ t('KANBAN.LOADING') }}
                </div>

                <div
                  v-else-if="contactsList.length === 0"
                  class="p-4 text-center"
                >
                  <p class="text-sm text-slate-500">
                    {{ t('KANBAN.FORM.NOTES.NO_CONTACTS') }}
                  </p>
                </div>

                <div
                  v-else
                  class="divide-y divide-slate-100 dark:divide-slate-700"
                >
                  <button
                    v-for="contact in contactsList"
                    :key="contact.id"
                    class="w-full px-4 py-3 text-left hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-700"
                    @click="selectContact(contact)"
                  >
                    <div class="flex items-center gap-3">
                      <!-- Avatar do contato -->
                      <div class="cursor-pointer" @click="handleViewContact">
                        <Avatar
                          v-if="contact.avatar_url"
                          :src="contact.avatar_url"
                          :name="contact.name"
                          :size="24"
                        />
                      </div>

                      <div class="flex items-center gap-2">
                        <h3
                          class="text-sm font-medium text-slate-900 dark:text-slate-100 cursor-pointer hover:text-woot-500 dark:hover:text-woot-400"
                          @click="handleViewContact"
                        >
                          {{ contact.name }}
                        </h3>
                      </div>
                    </div>
                    <!-- Informações adicionais -->
                    <div
                      v-if="contact.phone || contact.last_activity_at"
                      class="mt-1 ml-9 flex items-center gap-4 text-xs text-slate-500"
                    >
                      <span
                        v-if="contact.phone"
                        class="flex items-center gap-1"
                      >
                        <fluent-icon icon="call" size="12" />
                        {{ contact.phone }}
                      </span>
                      <span
                        v-if="contact.last_activity_at"
                        class="flex items-center gap-1"
                      >
                        <fluent-icon icon="alarm" size="12" />
                        {{ t('KANBAN.FORM.NOTES.LAST_ACTIVITY') }}:
                        {{ contact.last_activity_at }}
                      </span>
                    </div>
                  </button>
                </div>
              </div>
            </div>

            <!-- Seção de notas -->
            <div class="notes-section">
              <!-- Lista de notas -->
              <div v-for="note in notes" :key="note.id" class="note-card">
                <div class="note-layout">
                  <div class="note-content">
                    <div class="flex items-start justify-between">
                      <div class="note-text">
                        {{ note.text }}
                      </div>
                      <!-- Botões de ação -->
                      <div class="flex items-center gap-1">
                        <button
                          class="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
                          @click="startEditNote(note)"
                        >
                          <span class="icon-button">
                            <fluent-icon icon="edit" size="16" />
                          </span>
                        </button>
                        <button
                          class="p-1 text-slate-400 hover:text-ruby-600 dark:hover:text-ruby-400"
                          @click="removeNote(note.id)"
                        >
                          <span class="icon-button">
                            <fluent-icon icon="delete" size="16" />
                          </span>
                        </button>
                      </div>
                    </div>

                    <!-- Metadados da nota -->
                    <div class="note-metadata">
                      <div class="flex items-center gap-2">
                        <Avatar
                          :name="note.author"
                          :src="note.author_avatar"
                          :size="20"
                        />
                        <span class="note-author">{{ note.author }}</span>
                      </div>
                      <span class="note-date">
                        {{ formatDate(note.created_at || new Date()) }}
                      </span>
                    </div>

                    <!-- Arquivos não-imagem -->
                    <div v-if="hasNonImageAttachments(note)" class="note-files">
                      <div
                        v-for="attachment in getNonImageAttachments(note)"
                        :key="attachment.id"
                        class="file-attachment"
                      >
                        <div class="file-info">
                          <span class="file-icon">
                            {{ getFileIcon(attachment) }}
                          </span>
                          <a
                            :href="attachment.url"
                            target="_blank"
                            class="file-name"
                            :title="attachment.filename"
                          >
                            {{ attachment.filename }}
                          </a>
                        </div>
                        <button
                          class="file-action"
                          @click="removeAttachment(attachment)"
                        >
                          <fluent-icon icon="delete" size="12" />
                        </button>
                      </div>
                    </div>
                  </div>

                  <!-- Preview de imagens -->
                  <div v-if="hasImageAttachments(note)" class="note-images">
                    <div
                      v-for="attachment in getImageAttachments(note)"
                      :key="attachment.id"
                      class="image-preview"
                    >
                      <img
                        :src="attachment.url"
                        :alt="attachment.filename"
                        class="preview-image"
                        @click="openImagePreview(attachment.url)"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Tab de Checklist -->
          <div v-if="activeTab === 'checklist'" class="space-y-4">
            <div class="flex items-center justify-between mb-3">
              <div class="flex items-center gap-2">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ t('KANBAN.FORM.CHECKLIST.PROGRESS') }}
                </span>
                <span class="text-xs text-slate-500">
                  {{ completedItems }}/{{ totalItems }}
                  {{ t('KANBAN.FORM.CHECKLIST.ITEMS') }}
                </span>
              </div>
              <div class="flex items-center gap-2">
                <button
                  class="text-sm text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-400"
                  @click="hideCompletedItems = !hideCompletedItems"
                >
                  {{ t('KANBAN.FORM.CHECKLIST.HIDE_COMPLETED') }}
                </button>
                <button
                  class="text-sm text-ruby-600 hover:text-ruby-700 dark:text-ruby-400 dark:hover:text-ruby-300"
                  @click="deleteChecklist"
                >
                  {{ t('DELETE') }}
                </button>
              </div>
            </div>

            <!-- Barra de Progresso -->
            <div
              class="h-1.5 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden"
            >
              <div
                class="h-full bg-woot-500 transition-all duration-300 ease-out"
                :style="{ width: `${checklistProgress}%` }"
              />
            </div>

            <!-- Lista de Items -->
            <div v-if="checklistItems.length > 0" class="space-y-2">
              <div
                v-for="item in filteredChecklistItems"
                :key="item.id"
                class="group flex items-center gap-3 p-2 hover:bg-slate-50/50 dark:hover:bg-slate-800/50 rounded-lg transition-colors duration-200"
              >
                <!-- Checkbox customizado -->
                <label class="relative flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    :checked="item.completed"
                    class="peer h-5 w-5 cursor-pointer appearance-none rounded-md border-2 border-slate-300 dark:border-slate-600 checked:border-woot-500 dark:checked:border-woot-500 checked:bg-woot-500 dark:checked:bg-woot-500 transition-all duration-200"
                    @change="toggleChecklistItem(item)"
                  />
                  <fluent-icon
                    icon="checkmark"
                    size="12"
                    class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 text-white opacity-0 peer-checked:opacity-100 transition-opacity duration-200"
                  />
                </label>

                <!-- Texto do item e itens vinculados -->
                <div class="flex items-center gap-2 flex-1">
                  <span
                    :class="{
                      'line-through text-slate-400 dark:text-slate-500':
                        item.completed,
                      'text-slate-700 dark:text-slate-300': !item.completed,
                    }"
                    class="text-sm transition-colors duration-200"
                  >
                    {{ item.text }}
                  </span>

                  <!-- Item vinculado -->
                  <div
                    v-if="item.linked_item_id"
                    class="flex items-center gap-1 px-2 py-0.5 text-xs bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 rounded-full"
                  >
                    <fluent-icon icon="link" size="10" />
                    <span class="truncate max-w-[150px]">
                      {{
                        getLinkedItemDetails(item.linked_item_id)?.title ||
                        t('KANBAN.FORM.NOTES.ITEM_NOT_FOUND')
                      }}
                    </span>
                  </div>

                  <!-- Conversa vinculada -->
                  <div
                    v-if="item.linked_conversation_id"
                    class="flex items-center gap-1 px-2 py-0.5 text-xs bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 rounded-full"
                  >
                    <fluent-icon icon="chat" size="10" />
                    <span class="truncate max-w-[150px]">
                      #{{ item.linked_conversation_id }}
                    </span>
                  </div>

                  <!-- Contato vinculado -->
                  <div
                    v-if="item.linked_contact_id"
                    class="flex items-center gap-1 px-2 py-0.5 text-xs bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 rounded-full"
                  >
                    <fluent-icon icon="scan-person" size="10" />
                    <span class="truncate max-w-[150px]">
                      {{
                        contactsList.value.find(
                          c => c.id === item.linked_contact_id
                        )?.name || t('KANBAN.FORM.NOTES.CONTACT_NOT_FOUND')
                      }}
                    </span>
                  </div>
                </div>

                <!-- Botão de editar -->
                <button
                  class="opacity-0 group-hover:opacity-100 p-1 text-slate-400 hover:text-woot-500 dark:text-slate-500 dark:hover:text-woot-400 transition-all duration-200"
                  @click="startEditChecklistItem(item)"
                >
                  <fluent-icon icon="edit" size="14" />
                </button>

                <!-- Botão de remover -->
                <button
                  class="opacity-0 group-hover:opacity-100 p-1 text-slate-400 hover:text-ruby-500 dark:text-slate-500 dark:hover:text-ruby-400 transition-all duration-200"
                  @click="removeChecklistItem(item)"
                >
                  <fluent-icon icon="dismiss" size="14" />
                </button>
              </div>
            </div>

            <!-- Input para novo item -->
            <div class="mt-3">
              <div class="flex gap-2 mb-2">
                <input
                  v-model="newChecklistItem"
                  type="text"
                  class="flex-1 h-10 px-3 text-sm border border-slate-200 rounded-lg focus:ring-1 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-800 dark:border-slate-700 dark:text-slate-300"
                  :placeholder="t('KANBAN.FORM.CHECKLIST.ADD_ITEM')"
                  @keyup.enter="
                    editingChecklistItemId
                      ? saveEditedChecklistItem()
                      : addChecklistItem()
                  "
                />

                <div class="flex gap-2">
                  <button
                    v-if="editingChecklistItemId"
                    class="text-sm text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-300"
                    @click="cancelEditChecklistItem"
                  >
                    {{ t('KANBAN.CANCEL') }}
                  </button>

                  <button
                    class="relative inline-flex items-center h-10 px-4 text-sm font-medium text-white bg-woot-500 hover:bg-woot-600 dark:bg-woot-600 dark:hover:bg-woot-700 rounded-lg transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                    :disabled="!newChecklistItem.trim()"
                    @click="
                      editingChecklistItemId
                        ? saveEditedChecklistItem()
                        : addChecklistItem()
                    "
                  >
                    <fluent-icon
                      :icon="
                        editingChecklistItemId ? 'checkmark' : 'add-circle'
                      "
                      class="mr-1.5"
                      size="14"
                    />
                    {{ editingChecklistItemId ? t('SAVE') : t('ADD') }}
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Nova Tab de Anexos -->
          <div v-if="activeTab === 'attachments'" class="space-y-4">
            <!-- Botão de upload -->
            <div class="flex justify-between items-center">
              <FileUpload
                ref="uploadItem"
                :accept="ALLOWED_FILE_TYPES"
                @input-file="handleItemAttachment"
              >
                <button
                  class="primary-button flex items-center gap-2"
                  :disabled="isUploadingAttachment"
                >
                  <fluent-icon icon="attach" size="16" />
                  {{ t('KANBAN.ITEM_DETAILS.ATTACHMENTS.ADD_FILE') }}
                  <span v-if="isUploadingAttachment">...</span>
                </button>
              </FileUpload>
            </div>

            <!-- Lista de anexos -->
            <div class="attachments-grid">
              <!-- Seção de Imagens -->
              <div
                v-if="getAllAttachments.some(isImage)"
                class="attachment-section"
              >
                <h4 class="section-title">
                  {{ t('KANBAN.ITEM_DETAILS.ATTACHMENTS.IMAGES') }}
                </h4>
                <div class="images-grid">
                  <div
                    v-for="attachment in getAllAttachments.filter(isImage)"
                    :key="attachment.id"
                    class="image-card"
                  >
                    <img
                      :src="attachment.url"
                      :alt="attachment.filename"
                      class="attachment-preview"
                      @click="openImagePreview(attachment.url)"
                    />
                    <div class="attachment-info">
                      <div class="flex flex-col">
                        <span class="attachment-name">{{
                          attachment.filename
                        }}</span>
                        <span class="attachment-source">
                          {{
                            attachment.source.type === 'note'
                              ? `Nota: ${attachment.source.text}`
                              : 'Anexo do item'
                          }}
                        </span>
                      </div>
                      <button
                        class="delete-button"
                        @click="removeAttachment(attachment)"
                      >
                        <fluent-icon icon="delete" size="12" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Seção de Outros Arquivos -->
              <div
                v-if="getAllAttachments.some(a => !isImage(a))"
                class="attachment-section"
              >
                <h4 class="section-title">
                  {{ t('KANBAN.ITEM_DETAILS.ATTACHMENTS.FILES') }}
                </h4>
                <div class="files-grid">
                  <div
                    v-for="attachment in getAllAttachments.filter(
                      a => !isImage(a)
                    )"
                    :key="attachment.id"
                    class="file-card"
                  >
                    <div class="file-info">
                      <span class="file-icon">
                        {{ getFileIcon(attachment) }}
                      </span>
                      <div class="flex flex-col">
                        <a
                          :href="attachment.url"
                          target="_blank"
                          class="file-name"
                          :title="attachment.filename"
                        >
                          {{ attachment.filename }}
                        </a>
                        <span class="file-source">
                          {{
                            attachment.source.type === 'note'
                              ? `Nota: ${attachment.source.text}`
                              : 'Anexo do item'
                          }}
                        </span>
                      </div>
                    </div>
                    <button
                      class="delete-button"
                      @click="removeAttachment(attachment)"
                    >
                      <fluent-icon icon="delete" size="12" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Tab de Histórico -->
          <div v-if="activeTab === 'history'" class="space-y-4">
            <div class="flex justify-end mb-2">
              <button
                class="text-xs text-slate-500 hover:text-slate-700 dark:hover:text-slate-300"
                @click="showDebug = !showDebug"
              >
                {{
                  showDebug ? t('KANBAN.DEBUG.HIDE') : t(' KANBAN.DEBUG.SHOW')
                }}
              </button>
            </div>

            <div
              v-if="showDebug"
              class="mb-4 p-4 bg-gray-100 dark:bg-gray-800 rounded-lg overflow-auto max-h-96"
            >
              <pre class="text-xs">{{
                JSON.stringify(props.item.item_details?.activities, null, 2)
              }}</pre>
            </div>

            <div
              v-if="history.length === 0"
              class="p-4 text-center bg-slate-50 dark:bg-slate-800 rounded-lg"
            >
              <p class="text-sm text-slate-600 dark:text-slate-400">
                {{ t('KANBAN.HISTORY.NO_ACTIVITY') }}
              </p>
            </div>
            <div v-else class="history-timeline">
              <div
                v-for="(event, index) in history"
                :key="event.id"
                class="history-item"
              >
                <!-- Ícone e linha de conexão -->
                <div class="history-connector">
                  <div class="history-icon">
                    <fluent-icon :icon="event.icon" size="16" />
                  </div>
                </div>

                <!-- Conteúdo do evento -->
                <div class="history-content">
                  <div class="history-header">
                    <div class="flex items-center gap-2">
                      <span class="history-title">
                        {{ event.title }}
                      </span>
                    </div>
                    <span class="history-date">
                      {{ formatDate(event.created_at) }}
                    </span>
                  </div>

                  <div class="history-details">
                    <p class="history-text">{{ event.details }}</p>
                  </div>

                  <div class="history-author">
                    <Avatar
                      v-if="event.user"
                      :name="event.user.name"
                      :src="event.user.avatar_url"
                      :size="20"
                    />
                    <span class="text-xs text-slate-600 dark:text-slate-400">
                      {{ event.user ? event.user.name : t('SYSTEM') }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Tab Campos Personalizados -->
          <div v-if="activeTab === 'custom_fields'" class="space-y-6">
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center gap-3">
                <div
                  class="w-10 h-10 rounded-lg bg-woot-50 dark:bg-woot-900/20 flex items-center justify-center"
                >
                  <fluent-icon icon="edit" size="20" class="text-woot-500" />
                </div>
                <div>
                  <h3
                    class="text-base font-medium text-slate-900 dark:text-slate-100"
                  >
                    {{ t('KANBAN.CUSTOM_FIELDS.TITLE') }}
                  </h3>
                  <p class="text-sm text-slate-500">
                    {{ t('KANBAN.CUSTOM_FIELDS.CONVERSATION_ATTRIBUTES')
                    }}{{ props.item.item_details?.conversation_id }}
                  </p>
                </div>
              </div>
            </div>

            <div
              v-if="customAttributes.length > 0"
              class="grid gap-4 md:grid-cols-2"
            >
              <div
                v-for="attribute in customAttributes"
                :key="attribute.attribute_key"
                class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 p-4 hover:shadow-sm transition-shadow"
              >
                <div class="flex items-start justify-between">
                  <div class="space-y-1">
                    <h4
                      class="text-sm font-medium text-slate-900 dark:text-slate-100"
                    >
                      {{ attribute.attribute_display_name }}
                    </h4>
                    <p class="text-xs text-slate-500">
                      {{ attribute.attribute_description }}
                    </p>
                  </div>
                  <span
                    class="px-2 py-1 text-xs rounded-full"
                    :class="{
                      'bg-woot-50 text-woot-600 dark:bg-woot-900/20 dark:text-woot-400':
                        conversationAttributes[attribute.attribute_key],
                      'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400':
                        !conversationAttributes[attribute.attribute_key],
                    }"
                  >
                    {{ attribute.attribute_input_type }}
                  </span>
                </div>

                <div
                  class="mt-3 pt-3 border-t border-slate-100 dark:border-slate-700"
                >
                  <div class="flex items-center gap-2">
                    <span
                      class="text-sm font-medium text-slate-700 dark:text-slate-300"
                    >
                      {{
                        conversationAttributes[attribute.attribute_key] ||
                        t('KANBAN.CUSTOM_FIELDS.NOT_FILLED')
                      }}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <div
              v-else
              class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-6 text-center"
            >
              <div
                class="w-12 h-12 mx-auto mb-4 rounded-full bg-slate-100 dark:bg-slate-700 flex items-center justify-center"
              >
                <fluent-icon icon="form" size="24" class="text-slate-400" />
              </div>
              <h3
                class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
              >
                {{ t('KANBAN.CUSTOM_FIELDS.NO_CUSTOM_FIELDS') }}
              </h3>
              <p class="text-sm text-slate-500">
                {{ t('KANBAN.CUSTOM_FIELDS.NO_CUSTOM_FIELDS_DESCRIPTION') }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Botões de Ação -->
      <div class="flex justify-end space-x-2 pt-4 p-3">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ t('KANBAN.ACTIONS.CLOSE') }}
        </woot-button>
        <woot-button
          variant="solid"
          color-scheme="primary"
          @click="$emit('edit', item)"
        >
          {{ t('KANBAN.ACTIONS.EDIT') }}
        </woot-button>
      </div>
    </div>

    <!-- Bloco Direito (Novo) -->
    <div
      class="w-1/3 p-4 border-l border-slate-200 dark:border-slate-700 space-y-6"
    >
      <!-- Seção de Ações Rápidas -->
      <div
        class="quick-actions bg-white dark:bg-slate-800 rounded-lg p-4 border border-slate-200 dark:border-slate-700"
      >
        <h3 class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-3">
          {{ t('KANBAN.QUICK_ACTIONS') }}
        </h3>
        <div class="grid grid-cols-4 gap-2">
          <button
            v-for="action in quickActions"
            :key="action.id"
            class="quick-action-btn"
            :class="{
              'hover:bg-emerald-50 dark:hover:bg-emerald-900/20 hover:text-emerald-600 dark:hover:text-emerald-400':
                action.color === 'emerald',
              'hover:bg-violet-50 dark:hover:bg-violet-900/20 hover:text-violet-600 dark:hover:text-violet-400':
                action.color === 'violet',
              'hover:bg-amber-50 dark:hover:bg-amber-900/20 hover:text-amber-600 dark:hover:text-amber-400':
                action.color === 'amber',
              'hover:bg-sky-50 dark:hover:bg-sky-900/20 hover:text-sky-600 dark:hover:text-sky-400':
                action.color === 'sky',
            }"
            @click="handleQuickAction(action.id)"
          >
            <fluent-icon
              :icon="action.icon"
              size="20"
              :class="{
                'text-emerald-500 dark:text-emerald-400':
                  action.color === 'emerald',
                'text-violet-500 dark:text-violet-400':
                  action.color === 'violet',
                'text-amber-500 dark:text-amber-400': action.color === 'amber',
                'text-sky-500 dark:text-sky-400': action.color === 'sky',
              }"
            />
          </button>
        </div>
      </div>

      <!-- Seção de Chat Rápido -->
      <div
        class="quick-chat bg-white dark:bg-slate-800 rounded-lg p-4 border border-slate-200 dark:border-slate-700"
      >
        <div class="flex items-center justify-between mb-3">
          <div class="flex items-center gap-2">
            <Avatar
              v-if="conversationData?.contact"
              :src="conversationData.contact.thumbnail"
              :name="conversationData.contact.name"
              :size="24"
            />
            <h3 class="text-sm font-medium text-slate-900 dark:text-slate-100">
              {{ conversationData?.contact?.name || t('KANBAN.QUICK_CHAT') }}
            </h3>
          </div>
          <span class="text-xs text-slate-500">{{
            conversationData?.contact?.email
          }}</span>
        </div>
        <div class="chat-messages space-y-3 max-h-[300px] overflow-y-auto mb-3">
          <div
            v-for="message in messages"
            :key="message.id"
            :class="[
              'flex gap-2 mb-2',
              message.isMe ? 'justify-end' : 'justify-start',
            ]"
          >
            <div
              :class="[
                'max-w-[80%] p-2 rounded-lg text-sm',
                message.isMe
                  ? 'bg-woot-50 dark:bg-woot-900/20 text-woot-800 dark:text-woot-100'
                  : 'bg-slate-100 dark:bg-slate-700 text-slate-800 dark:text-slate-200',
              ]"
            >
              {{ message.text }}
              <div class="text-[10px] text-slate-500 mt-1">
                {{ message.timestamp }}
              </div>
            </div>
          </div>
          <div
            v-if="messages.length === 0"
            class="text-center text-gray-500 py-4"
          >
            Nenhuma mensagem encontrada
          </div>
        </div>
        <div class="flex gap-2">
          <input
            v-model="newMessage"
            type="text"
            class="flex-1 px-3 py-2 border border-slate-200 dark:border-slate-700 rounded-lg bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-woot-500/20"
            :placeholder="
              t('KANBAN.FORM.CONVERSATION.FOOTER.MESSAGE_INPUT_PLACEHOLDER')
            "
            @keyup.enter="sendMessage(newMessage)"
          />
          <button
            class="flex items-center justify-center w-10 h-10 text-white bg-woot-500 rounded-lg hover:bg-woot-600 focus:outline-none focus:ring-2 focus:ring-woot-500/20"
            @click="sendMessage(newMessage)"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- Modal de Mover -->
  <Modal
    v-if="showMoveModal"
    :show="showMoveModal"
    @close="showMoveModal = false"
  >
    <div class="p-4 space-y-4">
      <h3 class="text-lg font-medium text-slate-900 dark:text-slate-100">
        {{ t('KANBAN.BULK_ACTIONS.MOVE.TITLE') }}
      </h3>

      <!-- Seletor de Funil -->
      <div class="space-y-2">
        <label
          class="block text-sm font-medium text-slate-700 dark:text-slate-300"
        >
          {{ t('KANBAN.FORM.FUNNEL.LABEL') }}
        </label>
        <FunnelSelector v-model="moveForm.funnel_id" class="h-10" />
      </div>

      <!-- Seletor de Etapa -->
      <div class="space-y-2">
        <label
          class="block text-sm font-medium text-slate-700 dark:text-slate-300"
        >
          {{ t('KANBAN.FORM.STAGE.LABEL') }}
        </label>
        <select
          v-model="moveForm.funnel_stage"
          class="w-full h-10 px-3 py-2 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500"
        >
          <option
            v-for="stage in availableStages"
            :key="stage.id"
            :value="stage.id"
          >
            {{ stage.name }}
          </option>
        </select>
      </div>

      <!-- Botões -->
      <div class="flex justify-end gap-2 mt-4">
        <button
          class="px-4 py-2 text-sm text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
          @click="showMoveModal = false"
        >
          {{ t('KANBAN.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 text-sm text-white bg-woot-500 hover:bg-woot-600 rounded-lg transition-colors"
          @click="handleMove"
        >
          {{ t('KANBAN.MOVE') }}
        </button>
      </div>
    </div>
  </Modal>

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
          {{ t('KANBAN.SEND_MESSAGE.TITLE') }}
        </h3>
      </header>

      <div class="settings-content">
        <SendMessageTemplate
          :conversation-id="props.item.item_details?.conversation_id"
          :current-stage="props.item.funnel_stage || ''"
          :contact="props.item.item_details?.conversation?.contact"
          :conversation="props.item.item_details?.conversation"
          :item="props.item"
          @close="() => (showSendMessageModal = false)"
          @send="handleSendMessage"
        />
      </div>
    </div>
  </Modal>
</template>

<style scoped>
.kanban-details {
  max-height: 90vh;
  overflow-y: auto;
  -ms-overflow-style: none; /* IE and Edge */
  scrollbar-width: none; /* Firefox */
}

/* Oculta scrollbar para Chrome, Safari e Opera */
.kanban-details::-webkit-scrollbar {
  display: none;
}

/* Oculta scrollbar para elementos com custom-scrollbar também */
.custom-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

.custom-scrollbar::-webkit-scrollbar {
  display: none;
}

.header-section {
  @apply bg-white dark:bg-slate-800
    rounded-lg
    p-4 mb-4
    border border-slate-100 dark:border-slate-700;
}

.info-grid {
  @apply grid gap-3 mt-3;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
}

/* Definição base do card */
.info-card {
  @apply relative overflow-hidden flex flex-col gap-1 p-3 rounded-lg transition-all duration-200
    bg-white dark:bg-slate-800 border dark:border-slate-700;
}

/* Cards com cores diferentes */
.info-card:nth-child(1) {
  @apply bg-woot-50 dark:bg-slate-800 border-woot-100 dark:border-woot-700/50;
}

.info-card:nth-child(2) {
  @apply bg-green-50 dark:bg-slate-800 border-green-100 dark:border-green-700/50;
}

.info-card:nth-child(3) {
  @apply bg-yellow-50 dark:bg-slate-800 border-yellow-100 dark:border-yellow-700/50;
}

.info-card:nth-child(4) {
  @apply bg-indigo-50 dark:bg-slate-800 border-indigo-100 dark:border-indigo-700/50;
}

.info-label {
  @apply text-xs font-semibold uppercase tracking-wide text-slate-600 dark:text-slate-400;
}

.info-content {
  @apply text-sm font-medium text-slate-900 dark:text-slate-100;
}

/* Hover e interações */
.info-card:hover {
  @apply transform -translate-y-0.5 shadow-sm dark:shadow-slate-900/50;
}

.conversation-card {
  background-color: var(--color-background-light);
  border-radius: 0.25rem;
  padding: 0.375rem;
  margin-top: 0.125rem;
}

.conversation-title {
  font-size: 0.8125rem;
  font-weight: 500;
  margin: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.unread-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 1rem;
  height: 1rem;
  padding: 0 0.25rem;
  font-size: 0.675rem;
  font-weight: 600;
  color: white;
  background-color: var(--color-error);
  border-radius: 9999px;
}

.loading-text {
  font-size: 0.875rem;
  color: var(--color-text-light);
}

.dark .loading-text {
  color: var(--color-text-dark);
}

.no-data-text {
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.value-text {
  font-weight: 600;
  color: var(--color-success);
}

.custom-scrollbar {
  scrollbar-width: thin;
  scrollbar-color: var(--color-scrollbar) transparent;
}

.custom-scrollbar::-webkit-scrollbar {
  width: 6px;
}

.custom-scrollbar::-webkit-scrollbar-track {
  background: transparent;
}

.custom-scrollbar::-webkit-scrollbar-thumb {
  background-color: var(--color-scrollbar);
  border-radius: 3px;
}

.dark .custom-scrollbar {
  scrollbar-color: var(--color-scrollbar-dark) transparent;
}

.dark .custom-scrollbar::-webkit-scrollbar-thumb {
  background-color: var(--color-scrollbar-dark);
}

:root {
  --color-background-light: #ffffff;
  --color-background-dark: #1e293b;
  --color-border-light: #e2e8f0;
  --color-border-dark: #334155;
  --color-heading-light: #475569;
  --color-heading-dark: #94a3b8;
  --color-body-light: #1e293b;
  --color-body-dark: #e2e8f0;
  --color-text-light: #64748b;
  --color-text-dark: #94a3b8;
  --color-text-muted: #64748b;
  --color-woot: #4f46e5;
  --color-error: #ef4444;
  --color-success: #10b981;
  --color-scrollbar: #94a3b8;
  --color-scrollbar-dark: #475569;
  --white: #ffffff;
  --color-warning: #f59e0b;
  --color-info: #6366f1;
  --color-card-gradient: rgba(255, 255, 255, 0.5);
  --color-card-gradient-darker: rgba(30, 41, 59, 0.5);
  --color-woot-rgb: 79, 70, 229;
  --color-success-rgb: 16, 185, 129;
  --color-warning-rgb: 245, 158, 11;
  --color-info-rgb: 99, 102, 241;
}

/* Adicione estes estilos */
.tab-content {
  transition: opacity 0.2s ease-in-out;
}

.tab-content-enter-active,
.tab-content-leave-active {
  transition: opacity 0.2s ease-in-out;
}

.tab-content-enter-from,
.tab-content-leave-to {
  opacity: 0;
}

.tabs-container {
  border-bottom: 1px solid var(--color-border-light);
  margin-bottom: 1rem;
}

.dark .tabs-container {
  border-color: var(--color-border-dark);
}

.tab-button {
  @apply px-4 py-2 text-sm font-medium relative transition-colors;

  &.tab-active {
    @apply text-woot-500;

    &::after {
      content: '';
      @apply absolute bottom-0 left-0 right-0 h-0.5 bg-woot-500;
    }
  }

  &.tab-inactive {
    @apply text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100;
  }
}

.tab-inactive:hover {
  color: var(--color-text-light);
}

.dark .tab-inactive {
  color: var(--color-text-dark);
}

.dark .tab-inactive:hover {
  color: var(--color-text-light);
}

.tab-counter {
  display: inline-flex;
  align-items: center;
  padding: 0.125rem 0.375rem;
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-text-muted);
  background-color: var(--color-background-light);
  border-radius: 9999px;
}

.dark .tab-counter {
  background-color: var(--color-background-dark);
}

.tab-active .tab-counter {
  color: var(--color-woot);
  background-color: var(--color-woot-50);
}

.dark .tab-active .tab-counter {
  background-color: rgba(79, 70, 229, 0.1);
}

.note-attachments {
  @apply mt-4;
}

.action-button {
  @apply flex items-center justify-center w-10 h-10 rounded-lg
         text-slate-600 hover:text-slate-900
         dark:text-slate-400 dark:hover:text-slate-200
         bg-slate-50 hover:bg-slate-100
         dark:bg-slate-700 dark:hover:bg-slate-600
         transition-all duration-200;

  &:disabled {
    @apply opacity-50 cursor-not-allowed;
  }
}

.primary-button {
  @apply px-4 py-2 text-sm font-medium text-white
         bg-woot-500 hover:bg-woot-600
         dark:bg-woot-600 dark:hover:bg-woot-700
         rounded-lg transition-colors;

  &:disabled {
    @apply opacity-50 cursor-not-allowed;
  }
}

.notes-container {
  @apply flex flex-col gap-4;
}

.notes-container.with-preview {
  @apply grid grid-cols-2 gap-4;
}

.notes-content {
  @apply flex-1;
}

.images-preview {
  @apply space-y-4 border-l dark:border-slate-700 pl-4;
}

.image-preview-item {
  @apply rounded-lg overflow-hidden bg-slate-50 dark:bg-slate-700;
}

.preview-image {
  @apply w-24 h-24 object-cover rounded-lg cursor-pointer
         hover:opacity-90 transition-opacity;
}

.note-card {
  @apply bg-white dark:bg-slate-800 rounded-lg p-4 mb-4
         border border-slate-200 dark:border-slate-700;
}

.note-layout {
  @apply flex justify-between gap-4;
}

.note-content {
  @apply flex-1 flex flex-col justify-between;
}

.note-text {
  @apply flex-1 text-slate-700 dark:text-slate-300 whitespace-pre-wrap mb-4;
}

.note-metadata {
  @apply flex items-center justify-between text-sm
         text-slate-500 dark:text-slate-400 mb-3;
}

.note-author {
  @apply font-medium;
}

.note-date {
  @apply text-xs;
}

.note-files {
  @apply mt-4 space-y-2 border-t border-slate-100 dark:border-slate-700 pt-4;
}

.file-attachment {
  @apply flex items-center justify-between p-2
         bg-slate-50 dark:bg-slate-700
         rounded-lg text-sm;
}

.file-info {
  @apply flex items-center gap-1.5 flex-1 min-w-0;
}

.file-icon {
  @apply flex-shrink-0 text-slate-400;
}

.file-name {
  @apply text-[10px] hover:text-woot-500 dark:hover:text-woot-400
         text-slate-700 dark:text-slate-300 max-w-[150px]
         whitespace-nowrap;
}

.file-action {
  @apply p-1.5 text-slate-400 hover:text-ruby-500
         dark:text-slate-500 dark:hover:text-ruby-400
         rounded-md hover:bg-slate-100 dark:hover:bg-slate-600
         transition-colors;
}

.note-images {
  @apply flex-shrink-0 flex flex-col gap-3 w-24;
}

.image-preview {
  @apply rounded-lg overflow-hidden bg-slate-50 dark:bg-slate-700;
}

.preview-image {
  @apply w-24 h-24 object-cover rounded-lg cursor-pointer
         hover:opacity-90 transition-opacity;
}

/* Quando não há imagens, o conteúdo ocupa todo o espaço */
.note-layout:not(:has(.note-images)) .note-content {
  @apply w-full;
}

/* Ajuste para telas menores */
@media (max-width: 640px) {
  .note-layout {
    @apply flex-col gap-3;
  }

  .note-images {
    @apply w-full flex-row flex-wrap;
  }

  .preview-image {
    @apply w-16 h-16;
  }
}

/* Adicione estes estilos para os botões de ação */
.note-actions {
  @apply flex items-center gap-1;
}

.note-action-button {
  @apply p-1 text-slate-400 transition-colors;
}

.note-action-button:hover {
  @apply text-slate-600 dark:text-slate-300;
}

.note-action-button.delete:hover {
  @apply text-ruby-600 dark:text-ruby-400;
}

.icon-button {
  @apply flex items-center justify-center w-6 h-6 rounded-full
         transition-colors duration-200;
}

.icon-button:hover {
  @apply bg-slate-100 dark:bg-slate-700;
}

.attachments-grid {
  @apply space-y-6;
}

.attachment-section {
  @apply space-y-3;
}

.section-title {
  @apply text-sm font-medium text-slate-700 dark:text-slate-300;
}

.images-grid {
  @apply grid grid-cols-8 gap-2;
}

.image-card {
  @apply rounded-md overflow-hidden bg-slate-50 dark:bg-slate-700
         border border-slate-200 dark:border-slate-600;
}

.attachment-preview {
  @apply w-full h-16 object-cover cursor-pointer
         hover:opacity-90 transition-opacity;
}

.attachment-info {
  @apply p-1 flex items-center justify-between;
}

.attachment-name {
  @apply text-[10px] text-slate-700 dark:text-slate-300 truncate max-w-[80px];
}

.files-grid {
  @apply space-y-2;
}

.file-card {
  @apply flex items-center justify-between p-2
          bg-slate-50 dark:bg-slate-700 rounded-lg;
}

.delete-button {
  @apply p-1 text-slate-400 hover:text-ruby-500
         dark:text-slate-500 dark:hover:text-ruby-400
         rounded-md hover:bg-slate-100 dark:hover:bg-slate-600
         transition-colors;
}

.attachment-source,
.file-source {
  @apply text-[10px] text-slate-500 dark:text-slate-400 mt-0.5 truncate max-w-[80px];
}

.note-input-section {
  @apply space-y-2;
}

/* Adicione estes estilos */
.selected-file-preview {
  @apply mt-1 px-2 py-1 text-xs bg-slate-50 dark:bg-slate-700
         rounded border border-slate-200 dark:border-slate-600;
}

.history-timeline {
  @apply relative mt-8;
}

.history-item {
  @apply relative pb-12 pl-16;
}

.history-connector {
  @apply absolute left-0 top-0 bottom-0 w-16;
}

.history-icon {
  @apply absolute left-0 z-10 flex items-center justify-center w-8 h-8
          rounded-full bg-white dark:bg-slate-800 border-2 border-woot-500
          text-woot-500;
}

/* Adiciona a linha vertical */
.history-connector::after {
  content: '';
  @apply absolute left-4 top-8 bottom-0 w-0.5 -translate-x-1/2
          bg-woot-500;
}

/* Remove a linha do último item */
.history-item:last-child .history-connector::after {
  @apply hidden;
}

.history-content {
  @apply bg-white dark:bg-slate-800 rounded-lg p-4
          border border-slate-100 dark:border-slate-700
          shadow-sm;
}

.history-header {
  @apply flex items-center justify-between mb-3;
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

.settings-modal {
  @apply flex flex-col;

  .settings-header {
    @apply p-4 border-b border-slate-100 dark:border-slate-700;
  }

  .settings-content {
    @apply p-4 space-y-4;
  }
}

/* Estilos adicionais para o bloco direito */
.quick-actions button:hover {
  transform: translateY(-1px);
  transition: transform 0.2s ease;
}

.chat-messages {
  scrollbar-width: thin;
  scrollbar-color: var(--color-woot) transparent;
}

.chat-messages::-webkit-scrollbar {
  width: 4px;
}

.chat-messages::-webkit-scrollbar-track {
  background: transparent;
}

.chat-messages::-webkit-scrollbar-thumb {
  background: var(--color-woot);
  border-radius: 2px;
}

/* Estilos adicionais para os botões de ação rápida */
.quick-action-btn {
  @apply flex items-center justify-center p-3 rounded-xl transition-all duration-200 bg-slate-50 dark:bg-slate-800/50;
}

.quick-action-btn:hover {
  @apply transform -translate-y-0.5 shadow-lg;
}

.quick-action-btn:active {
  @apply transform translate-y-0 shadow-md;
}
</style>

_file>
