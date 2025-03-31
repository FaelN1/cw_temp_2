<script setup>
import { ref, watchEffect, computed, watch, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import KanbanAPI from '../../../../api/kanban';
import FunnelSelector from './FunnelSelector.vue';
import conversationAPI from '../../../../api/inbox/conversation';
import { emitter } from 'shared/helpers/mitt';
import AttributeAPI from '../../../../api/attributes';

// Modificar a função toLocalISOString para retornar o formato exato
const toLocalISOString = (date, includeTime = true) => {
  if (!date) return null;
  try {
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');

    if (!includeTime) {
      return `${year}-${month}-${day}`;
    }

    const hours = String(d.getHours()).padStart(2, '0');
    const minutes = String(d.getMinutes()).padStart(2, '0');

    // Retornar no formato exato para datetime-local: YYYY-MM-DDThh:mm
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  } catch (error) {
    console.error('Erro ao formatar data:', error);
    return null;
  }
};

const { t } = useI18n();
const store = useStore();
const emit = defineEmits(['saved', 'close']);
const activeTab = ref('general');

const props = defineProps({
  funnelId: {
    type: [String, Number],
    required: true,
  },
  stage: {
    type: String,
    required: true,
  },
  position: {
    type: Number,
    default: 0,
  },
  initialData: {
    type: Object,
    default: null,
  },
  isEditing: {
    type: Boolean,
    default: false,
  },
  currentConversation: {
    type: Object,
    default: null,
  },
  initialDate: {
    type: Date,
    default: null,
  },
});

const loading = ref(false);
const loadingAgents = ref(false);
const selectedFunnel = computed(
  () => store.getters['funnel/getSelectedFunnel']
);

// Computed para obter as etapas do funil selecionado
const availableStages = computed(() => {
  if (!selectedFunnel.value?.stages) return [];

  return Object.entries(selectedFunnel.value.stages)
    .map(([id, stage]) => ({
      id,
      name: stage.name,
      position: stage.position,
    }))
    .sort((a, b) => a.position - b.position);
});

// Refs para controle da conversa
const showConversationInput = ref(
  !!props.initialData?.item_details?.conversation_id
);
const conversations = ref([]);
const loadingConversations = ref(false);

// Ref para controlar a visibilidade do input de valor
const showValueInput = ref(!!props.initialData?.item_details?.value);

// Atualizar a função para verificar se tem agendamento
const hasScheduling = computed(() => {
  return !!(
    props.initialData?.item_details?.scheduled_at ||
    props.initialData?.item_details?.deadline_at ||
    props.initialDate
  );
});

// Atualizar a ref showScheduling para usar o computed
const showScheduling = ref(hasScheduling.value);

// Forçar showScheduling a ser true se houver agendamento
// Isso garante que o checkbox esteja marcado
if (hasScheduling.value) {
  showScheduling.value = true;
}

// Atualizar o schedulingType para usar o tipo correto do item
const schedulingType = ref(
  props.initialData?.item_details?.scheduling_type ||
    (props.initialData?.item_details?.scheduled_at ? 'schedule' : 'deadline')
);

// Adicione estas refs e computed
const currencySymbol = ref('R$'); // Pode ser configurável posteriormente
const rawValue = ref('');

// Adicione as opções de moeda
const currencyOptions = [
  { symbol: 'R$', code: 'BRL', locale: 'pt-BR' },
  { symbol: '$', code: 'USD', locale: 'en-US' },
  { symbol: '€', code: 'EUR', locale: 'de-DE' },
];

const selectedCurrency = ref(currencyOptions[0]); // Default para BRL

// Atualizar o form.value para incluir as ofertas e datas
const form = ref({
  title: props.initialData?.title || '',
  description:
    props.initialData?.item_details?.description ||
    props.initialData?.description ||
    '',
  funnel_id: props.funnelId,
  funnel_stage: props.stage,
  position: props.position,
  item_details: {
    title: props.initialData?.title || '',
    description:
      props.initialData?.item_details?.description ||
      props.initialData?.description ||
      '',
    value: null,
    currency: currencyOptions[0],
    offers: [],
    priority:
      props.initialData?.item_details?.priority ||
      props.initialData?.priority ||
      'none',
    agent_id: props.initialData?.item_details?.agent_id || null,
    conversation_id: props.initialData?.item_details?.conversation_id || null,
    scheduling_type: schedulingType.value,
    scheduled_at: null,
    deadline_at: null,
  },
  custom_attributes: props.initialData?.custom_attributes || {},
});

// Log inicial para debug
console.log(
  '[DEBUG] KanbanItemForm - initialData recebido:',
  props.initialData
);
console.log(
  '[DEBUG] KanbanItemForm - description do initialData:',
  props.initialData?.description
);
console.log(
  '[DEBUG] KanbanItemForm - item_details do initialData:',
  props.initialData?.item_details
);
console.log(
  '[DEBUG] KanbanItemForm - description dentro de item_details:',
  props.initialData?.item_details?.description
);
console.log(
  '[DEBUG] KanbanItemForm - prioridade no initialData:',
  props.initialData?.priority
);
console.log(
  '[DEBUG] KanbanItemForm - prioridade dentro do item_details:',
  props.initialData?.item_details?.priority
);
console.log(
  '[DEBUG] KanbanItemForm - prioridade inicializada no form:',
  form.value.item_details.priority
);

// Adicione estas refs
const customAttributes = ref([]);
const loadingAttributes = ref(false);
const conversationAttributes = ref({});

// Adicione esta função para buscar os atributos
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

// Adicione esta função para buscar os valores dos atributos da conversa
const fetchConversationAttributes = async () => {
  if (!form.value.item_details?.conversation_id) return;

  try {
    // Use os atributos que já vêm na conversa
    const conversation = form.value.item_details.conversation;
    if (conversation?.custom_attributes) {
      conversationAttributes.value = conversation.custom_attributes;
    }
  } catch (error) {
    console.error('Erro ao carregar atributos da conversa:', error);
  }
};

// Modifique o onMounted para remover a busca de agentes
onMounted(async () => {
  // Carregar agentes do store
  loadingAgents.value = true;
  try {
    await store.dispatch('agents/get');
  } catch (error) {
    console.error('Erro ao carregar agentes:', error);
  } finally {
    loadingAgents.value = false;
  }

  await fetchCustomAttributes();
  if (props.initialData?.item_details?.conversation_id) {
    await fetchConversationAttributes();
  }

  // Se tiver conversa atual ou estiver editando, buscar conversas
  if (
    props.currentConversation ||
    (props.isEditing && props.initialData?.item_details?.conversation_id)
  ) {
    showConversationInput.value = true;
    fetchConversations();
  }

  // Adicione este onMounted para gerenciar o clique fora do dropdown
  const handleClickOutside = event => {
    if (
      showCurrencySelector.value &&
      !event.target.closest('.currency-selector')
    ) {
      showCurrencySelector.value = false;
    }
  };

  document.addEventListener('mousedown', handleClickOutside);
  onUnmounted(() => {
    document.removeEventListener('mousedown', handleClickOutside);
  });

  if (props.initialData?.item_details?.value) {
    // Adiciona a oferta principal
    offers.value.push({
      description: '',
      value: props.initialData.item_details.value,
      currency: props.initialData.item_details.currency || currencyOptions[0],
    });
  }

  // Adiciona as ofertas adicionais
  if (props.initialData?.item_details?.offers?.length) {
    offers.value.push(...props.initialData.item_details.offers);
  }

  // Sincronizar valores de agendamento
  if (hasScheduling.value) {
    showScheduling.value = true;

    if (props.initialData?.item_details?.scheduled_at) {
      schedulingType.value = 'schedule';
      form.value.item_details.scheduled_at = toLocalISOString(
        props.initialData.item_details.scheduled_at
      );
      console.log(
        '[DEBUG] Agendamento com hora configurado:',
        form.value.item_details.scheduled_at
      );
    } else if (props.initialData?.item_details?.deadline_at) {
      schedulingType.value = 'deadline';
      form.value.item_details.deadline_at = toLocalISOString(
        props.initialData.item_details.deadline_at,
        false // Apenas data para prazo
      );
      console.log(
        '[DEBUG] Prazo configurado:',
        form.value.item_details.deadline_at
      );
    } else if (props.initialDate) {
      // Se houver uma data inicial, configure como prazo
      schedulingType.value = 'deadline';
      form.value.item_details.deadline_at = toLocalISOString(
        props.initialDate,
        false // Apenas data para prazo
      );
      console.log(
        '[DEBUG] Data inicial configurada como prazo:',
        form.value.item_details.deadline_at
      );
    }

    console.log(
      '[DEBUG SCHEDULING] Checkbox de agendamento marcado:',
      showScheduling.value
    );
    console.log(
      '[DEBUG SCHEDULING] Tipo de agendamento:',
      schedulingType.value
    );
    console.log(
      '[DEBUG SCHEDULING] Data de agendamento:',
      form.value.item_details.scheduled_at
    );
    console.log(
      '[DEBUG SCHEDULING] Data de prazo:',
      form.value.item_details.deadline_at
    );
  }
});

// Adicionar watch para o campo showScheduling
watch(showScheduling, newValue => {
  if (!newValue) {
    // Se o checkbox foi desmarcado, limpe os campos de agendamento
    form.value.item_details.scheduled_at = null;
    form.value.item_details.deadline_at = null;
    console.log('[DEBUG] Agendamento desativado, valores limpos');
  } else {
    console.log('[DEBUG] Agendamento ativado');
    // Se foi marcado mas não há tipo definido, defina um padrão
    if (!form.value.item_details.scheduling_type) {
      schedulingType.value = 'deadline';
      form.value.item_details.scheduling_type = 'deadline';
    }
  }
});

// Atualizar o watch do schedulingType
watch(schedulingType, (newType, oldType) => {
  if (newType === oldType) return;

  form.value.item_details.scheduling_type = newType;

  if (newType === 'deadline') {
    // Se mudar para deadline, preserva a data existente ou converte do scheduled_at
    if (
      !form.value.item_details.deadline_at &&
      form.value.item_details.scheduled_at
    ) {
      // Converter para o formato de date
      form.value.item_details.deadline_at = toLocalISOString(
        form.value.item_details.scheduled_at,
        false // Sem hora
      );
    }
    form.value.item_details.scheduled_at = null;
  } else {
    // Se mudar para schedule, preserva a data existente ou converte do deadline_at
    if (
      !form.value.item_details.scheduled_at &&
      form.value.item_details.deadline_at
    ) {
      // Converter para o formato de datetime-local
      const deadlineDate = new Date(form.value.item_details.deadline_at);
      // Define hora como meio-dia por padrão
      deadlineDate.setHours(12, 0, 0, 0);
      form.value.item_details.scheduled_at = toLocalISOString(deadlineDate);
    }
    form.value.item_details.deadline_at = null;
  }
});

// Função para buscar conversas
const fetchConversations = async () => {
  try {
    loadingConversations.value = true;
    // Se estiver editando, busca todas as conversas
    if (props.isEditing) {
      const response = await conversationAPI.get({});
      conversations.value = response.data.data.payload;
    } else if (props.currentConversation) {
      // Usa a conversa atual se fornecida
      conversations.value = [props.currentConversation];
    } else {
      // Caso contrário, busca todas as conversas
      const response = await conversationAPI.get({});
      conversations.value = response.data.data.payload;
    }
  } catch (error) {
    console.error('Erro ao carregar conversas:', error);
  } finally {
    loadingConversations.value = false;
  }
};

// Atualize a função de formatação para usar a moeda selecionada
const formatCurrencyInput = (e, index) => {
  const target = index === 'new' ? newOffer.value : offers.value[index];
  let value = e.target.value.replace(/[^\d.,]/g, '');
  value = value.replace(',', '.');

  const parts = value.split('.');
  if (parts.length > 2) {
    value = `${parts[0]}.${parts.slice(1).join('')}`;
  }

  rawValue.value = value;

  if (value) {
    const number = parseFloat(value);
    if (!isNaN(number)) {
      e.target.value = new Intl.NumberFormat(target.currency.locale, {
        style: 'currency',
        currency: target.currency.code,
      }).format(number);

      target.value = number;
    }
  }
};

// Atualize também a função de validação
const validateCurrencyInput = (e, index) => {
  const target = index === 'new' ? newOffer.value : offers.value[index];
  if (!rawValue.value) {
    e.target.value = '';
    target.value = null;
    return;
  }

  const number = parseFloat(rawValue.value);
  if (isNaN(number)) {
    e.target.value = '';
    target.value = null;
    return;
  }

  e.target.value = new Intl.NumberFormat(target.currency.locale, {
    style: 'currency',
    currency: target.currency.code,
  }).format(number);

  target.value = number;
};

// Atualiza o watch do showValueInput para limpar o valor quando desmarcar
watch(showValueInput, newValue => {
  if (!newValue) {
    form.value.item_details.value = null;
    rawValue.value = '';
  }
});

watch(showConversationInput, newValue => {
  if (!newValue) {
    form.value.item_details.conversation_id = null;
  } else {
    fetchConversations();
  }
});

// Atualiza o form quando o funil ou etapa mudar
watchEffect(() => {
  console.log('watchEffect: título atual', form.value.title);
  form.value = {
    ...form.value,
    funnel_id: selectedFunnel.value?.id || props.funnelId,
    funnel_stage: form.value.funnel_stage || props.stage,
    position: props.position,
    title:
      form.value.title ||
      props.initialData?.title ||
      props.initialData?.item_details?.title ||
      '',
    item_details: {
      ...form.value.item_details,
      title:
        form.value.title ||
        props.initialData?.title ||
        props.initialData?.item_details?.title ||
        '',
      description: form.value.description,
      priority:
        form.value.item_details.priority ||
        props.initialData?.item_details?.priority ||
        props.initialData?.priority ||
        'none',
      value:
        form.value.item_details.value || props.initialData?.item_details?.value,
      currency:
        form.value.item_details.currency ||
        props.initialData?.item_details?.currency,
      scheduled_at:
        form.value.item_details.scheduled_at ||
        props.initialData?.item_details?.scheduled_at,
      deadline_at:
        form.value.item_details.deadline_at ||
        props.initialData?.item_details?.deadline_at,
    },
  };
});

// Adicionar watch para sincronizar o título em tempo real
watch(
  () => form.value.title,
  newTitle => {
    if (form.value.item_details) {
      form.value.item_details.title = newTitle;
    }
  }
);

// Adicionar watch para sincronizar a descrição em tempo real
watch(
  () => form.value.description,
  newDescription => {
    if (form.value.item_details) {
      form.value.item_details.description = newDescription;
    }
  }
);

// Adicionar função para validar se a data é futura (1 minuto)
const isValidFutureDate = date => {
  const now = new Date();
  const selectedDate = new Date(date);
  // Adiciona 1 minuto ao tempo atual para comparação
  const minValidDate = new Date(now.getTime() + 60000); // 60000ms = 1 minuto
  return selectedDate >= minValidDate;
};

// Modificar a função validateForm para incluir a validação de data
const validateForm = () => {
  const errors = {};

  if (!form.value.title?.trim()) {
    errors.title = t('KANBAN.ERRORS.TITLE_REQUIRED');
  }

  if (!form.value.funnel_id) {
    errors.funnel_id = t('KANBAN.ERRORS.FUNNEL_REQUIRED');
  }

  if (!form.value.funnel_stage) {
    errors.funnel_stage = t('KANBAN.ERRORS.STAGE_REQUIRED');
  }

  // Validar data de agendamento
  if (
    form.value.item_details.scheduling_type === 'schedule' &&
    form.value.item_details.scheduled_at
  ) {
    if (!isValidFutureDate(form.value.item_details.scheduled_at)) {
      errors.scheduled_at =
        'O agendamento deve ser pelo menos 1 minuto no futuro';
    }
  }

  // Validar prazo
  if (
    form.value.item_details.scheduling_type === 'deadline' &&
    form.value.item_details.deadline_at
  ) {
    if (!isValidFutureDate(form.value.item_details.deadline_at)) {
      errors.deadline_at = 'O prazo deve ser pelo menos 1 minuto no futuro';
    }
  }

  if (Object.keys(errors).length > 0) {
    emitter.emit('newToastMessage', {
      message: errors[Object.keys(errors)[0]],
      type: 'error',
    });
    return errors;
  }

  return null;
};

const priorityOptions = [
  { id: 'none', name: t('KANBAN.PRIORITY_LABELS.NONE') },
  { id: 'low', name: t('KANBAN.PRIORITY_LABELS.LOW') },
  { id: 'medium', name: t('KANBAN.PRIORITY_LABELS.MEDIUM') },
  { id: 'high', name: t('KANBAN.PRIORITY_LABELS.HIGH') },
  { id: 'urgent', name: t('KANBAN.PRIORITY_LABELS.URGENT') },
];

// Função auxiliar para registrar atividades
const registerActivity = async (itemId, type, details) => {
  try {
    const newActivity = {
      id: Date.now(),
      type,
      details,
      created_at: new Date().toISOString(),
      user: {
        id: store.getters.getCurrentUser.id,
        name: store.getters.getCurrentUser.name,
        avatar_url: store.getters.getCurrentUser.avatar_url,
      },
    };

    const currentItem = await KanbanAPI.getItem(itemId);
    const activities = [
      ...(currentItem.data.item_details?.activities || []),
      newActivity,
    ];

    const payload = {
      ...currentItem.data,
      item_details: {
        ...currentItem.data.item_details,
        activities,
      },
    };

    await KanbanAPI.updateItem(itemId, payload);
  } catch (error) {
    console.error('Erro ao registrar atividade:', error);
  }
};

// Modificar handleSubmit para não usar agentsList
const handleSubmit = async e => {
  e.preventDefault();
  const errors = validateForm();
  if (errors) return;

  try {
    loading.value = true;

    // Garantir que título e descrição estejam sincronizados
    console.log(
      '[STORE-DEBUG] Título antes da sincronização:',
      form.value.title
    );
    form.value.item_details.title = form.value.title;
    form.value.item_details.description = form.value.description;
    console.log(
      '[STORE-DEBUG] Título após sincronização:',
      form.value.item_details.title
    );

    let finalItemDetails = {};

    // Se estiver editando, preservar os dados originais do item
    if (props.isEditing && props.initialData?.item_details) {
      // Clonar os dados originais para não modificá-los diretamente
      finalItemDetails = JSON.parse(
        JSON.stringify(props.initialData.item_details)
      );

      // Preservar explicitamente dados importantes
      // Isso mantém notes, checklist, attachments e activities intactos
      const fieldsToPreserve = [
        'notes',
        'checklist',
        'attachments',
        'activities',
      ];
      fieldsToPreserve.forEach(field => {
        if (props.initialData.item_details[field]) {
          finalItemDetails[field] = props.initialData.item_details[field];
        }
      });
    }

    // Atualizar apenas os campos que foram modificados
    const fieldsToUpdate = [
      'title',
      'description',
      'value',
      'currency',
      'priority',
      'agent_id',
      'conversation_id',
      'scheduling_type',
      'scheduled_at',
      'deadline_at',
      'custom_attributes',
    ];

    fieldsToUpdate.forEach(field => {
      if (form.value.item_details[field] !== undefined) {
        finalItemDetails[field] = form.value.item_details[field];
      }
    });

    // Garantir explicitamente que o título seja incluído
    finalItemDetails.title = form.value.title;
    console.log(
      '[STORE-DEBUG] Título nos dados finais:',
      finalItemDetails.title
    );

    // Adicionar/atualizar ofertas
    finalItemDetails.offers = offers.value.slice(1);

    // Se o primeiro item de ofertas existir, use-o como valor principal
    if (offers.value.length > 0) {
      finalItemDetails.value = offers.value[0].value;
      finalItemDetails.currency = offers.value[0].currency;
    }

    const payload = {
      ...form.value,
      item_details: finalItemDetails,
    };

    console.log('[STORE-DEBUG] Payload enviado para a API:', payload);

    const { data } = props.isEditing
      ? await KanbanAPI.updateItem(props.initialData.id, payload)
      : await KanbanAPI.createItem(payload);

    console.log('[STORE-DEBUG] Resposta da API após criação/edição:', data);
    console.log(
      '[STORE-DEBUG] Verificando se o item está no store antes de qualquer ação'
    );

    // Verificando store antes
    const storeItemsBefore = store.state.kanban.items;
    console.log(
      '[STORE-DEBUG] Itens no store antes:',
      storeItemsBefore.map(i => ({ id: i.id, stage: i.funnel_stage }))
    );

    try {
      // Verificando se itemUpdated existe
      console.log('[STORE-DEBUG] Chamando itemUpdated no store');
      await store.dispatch('kanban/itemUpdated');

      // Verificando store depois
      const storeItemsAfter = store.state.kanban.items;
      console.log(
        '[STORE-DEBUG] Itens no store depois:',
        storeItemsAfter.map(i => ({ id: i.id, stage: i.funnel_stage }))
      );
      console.log(
        '[STORE-DEBUG] Item recém criado/editado está no store:',
        storeItemsAfter.some(i => i.id === data.id)
      );
    } catch (e) {
      console.error('[STORE-DEBUG] Erro ao chamar itemUpdated:', e);
      console.log(
        '[STORE-DEBUG] Tentando chamar fetchKanbanItems como alternativa'
      );
      await store.dispatch('kanban/fetchKanbanItems');
    }

    emitter.emit('newToastMessage', {
      message: props.isEditing
        ? 'Item atualizado com sucesso'
        : 'Item criado com sucesso',
      action: { type: 'success' },
    });
    emit('saved', data);
  } catch (error) {
    console.error('[STORE-DEBUG] Erro ao salvar item:', error);
  } finally {
    loading.value = false;
  }
};

const showCurrencySelector = ref(false);

// Ref para nova oferta
const newOffer = ref({
  description: '',
  value: '',
  currency: currencyOptions[0],
});

// Refs para controle das ofertas
const offers = ref([]);

const currencySelectorIndex = ref(null);

// Funções para gerenciar ofertas
const addOffer = () => {
  if (newOffer.value.value && newOffer.value.description) {
    offers.value.push({
      description: newOffer.value.description,
      value: newOffer.value.value,
      currency: newOffer.value.currency,
    });

    // Atualiza o valor principal para referência
    form.value.item_details.value = offers.value[0].value;
    form.value.item_details.currency = offers.value[0].currency;

    newOffer.value = {
      description: '',
      value: '',
      currency: currencyOptions[0],
    };
  }
};

const removeOffer = index => {
  offers.value.splice(index, 1);

  // Se removeu a primeira oferta, atualiza o valor principal
  if (index === 0 && offers.value.length > 0) {
    const [firstOffer] = offers.value;
    form.value.item_details.value = firstOffer.value;
    form.value.item_details.currency = firstOffer.currency;
    form.value.item_details.description = firstOffer.description;
  } else if (offers.value.length === 0) {
    // Se não há mais ofertas, limpa os valores
    form.value.item_details.value = null;
    form.value.item_details.currency = currencyOptions[0];
    form.value.item_details.description = '';
  }

  // Atualiza as ofertas adicionais
  form.value.item_details.offers = offers.value.slice(1);
};

const toggleCurrencySelector = index => {
  currencySelectorIndex.value =
    currencySelectorIndex.value === index ? null : index;
};

const selectCurrency = (currency, index) => {
  if (index === 'new') {
    newOffer.value.currency = currency;
  } else {
    offers.value[index].currency = currency;
  }
  currencySelectorIndex.value = null;
};

// Adicione esta função no script
const formatCurrencyValue = (value, currency) => {
  if (!value) return '-';

  try {
    return new Intl.NumberFormat(currency.locale, {
      style: 'currency',
      currency: currency.code,
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(value);
  } catch (error) {
    console.error('Erro ao formatar valor:', error);
    return value.toString();
  }
};

// Adicione também uma função para adicionar nova oferta
const addNewOffer = () => {
  const newOffer = {
    description: '',
    value: '',
    currency: currencyOptions[0],
  };
  offers.value.push(newOffer);
};

// Adicione um watch para atualizar atributos quando a conversa mudar
watch(
  () => form.value.item_details?.conversation_id,
  async newId => {
    if (newId) {
      await fetchConversationAttributes();
    } else {
      conversationAttributes.value = {};
    }
  }
);
</script>

<template>
  <form
    class="flex flex-col gap-4 max-h-[85vh] overflow-y-auto w-full px-4"
    @submit.prevent="handleSubmit"
  >
    <!-- Tabs -->
    <div class="tabs-container">
      <div
        class="flex items-center gap-4 border-b border-slate-200 dark:border-slate-700"
      >
        <button
          type="button"
          class="tab-button"
          :class="[activeTab === 'general' ? 'tab-active' : 'tab-inactive']"
          @click="activeTab = 'general'"
        >
          <div class="flex items-center gap-2">
            <fluent-icon icon="document" size="16" />
            {{ t('KANBAN.TABS.GENERAL') }}
          </div>
        </button>

        <button
          type="button"
          class="tab-button"
          :class="[activeTab === 'pipeline' ? 'tab-active' : 'tab-inactive']"
          @click="activeTab = 'pipeline'"
        >
          <div class="flex items-center gap-2">
            <fluent-icon icon="task" size="16" />
            {{ t('KANBAN.TABS.PIPELINE') }}
          </div>
        </button>

        <button
          type="button"
          class="tab-button"
          :class="[activeTab === 'assignment' ? 'tab-active' : 'tab-inactive']"
          @click="activeTab = 'assignment'"
        >
          <div class="flex items-center gap-2">
            <fluent-icon icon="bot" size="16" />
            {{ t('KANBAN.TABS.ASSIGNMENT') }}
          </div>
        </button>

        <button
          type="button"
          class="tab-button"
          :class="[activeTab === 'scheduling' ? 'tab-active' : 'tab-inactive']"
          @click="activeTab = 'scheduling'"
        >
          <div class="flex items-center gap-2">
            <fluent-icon icon="calendar-clock" size="16" />
            {{ t('KANBAN.TABS.SCHEDULING') }}
          </div>
        </button>

        <button
          type="button"
          class="tab-button"
          :class="[
            activeTab === 'relationships' ? 'tab-active' : 'tab-inactive',
          ]"
          @click="activeTab = 'relationships'"
        >
          <div class="flex items-center gap-2">
            <fluent-icon icon="attach" size="16" />
            {{ t('KANBAN.TABS.RELATIONSHIPS') }}
          </div>
        </button>

        <button
          type="button"
          class="tab-button"
          :class="activeTab === 'custom_fields' ? 'tab-active' : 'tab-inactive'"
          @click.prevent.stop="activeTab = 'custom_fields'"
        >
          {{ t('KANBAN.TABS.CUSTOM_FIELDS') }}
        </button>
      </div>
    </div>

    <!-- Conteúdo das Tabs -->
    <div
      class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm"
    >
      <!-- Tab Dados Gerais -->
      <div v-if="activeTab === 'general'" class="space-y-6">
        <div class="flex items-center gap-3 mb-6">
          <div
            class="flex items-center justify-center w-8 h-8 rounded-lg bg-woot-50 dark:bg-woot-900/20"
          >
            <fluent-icon icon="document" size="18" class="text-woot-500" />
          </div>
          <h4 class="text-base font-medium text-slate-800 dark:text-slate-100">
            {{ t('KANBAN.TABS.GENERAL') }}
          </h4>
        </div>

        <!-- Título -->
        <div class="space-y-2">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300"
          >
            {{ t('KANBAN.FORM.TITLE.LABEL') }}
          </label>
          <input
            v-model="form.title"
            type="text"
            class="w-full px-4 py-3 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 shadow-sm"
            :placeholder="t('KANBAN.FORM.TITLE.PLACEHOLDER')"
            required
          />
        </div>

        <!-- Grid com Valor e Descrição -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <!-- Valor - Ocupa 1/3 -->
          <div class="lg:col-span-1">
            <div
              class="bg-gradient-to-br from-woot-50/50 to-white dark:from-slate-800/50 dark:to-slate-800 rounded-lg border border-woot-100 dark:border-slate-700 overflow-hidden"
            >
              <!-- Header do Card -->
              <div
                class="p-4 border-b border-woot-100/50 dark:border-slate-700/50"
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-4">
                    <span
                      class="text-sm font-medium text-slate-700 dark:text-slate-300"
                    >
                      {{ t('KANBAN.FORM.VALUE.LABEL') }}
                    </span>
                  </div>
                  <div class="flex items-center gap-2">
                    <input
                      id="has-value"
                      v-model="showValueInput"
                      type="checkbox"
                      class="w-4 h-4 text-woot-500 border-slate-300 rounded focus:ring-woot-500"
                    />
                    <label
                      for="has-value"
                      class="text-xs text-slate-600 dark:text-slate-400"
                    >
                      {{ t('KANBAN.FORM.VALUE.HAS_VALUE') }}
                    </label>
                  </div>
                </div>
              </div>

              <!-- Conteúdo do Card -->
              <div
                v-if="showValueInput"
                class="divide-y divide-slate-100 dark:divide-slate-700/50"
              >
                <!-- Formulário de Nova Oferta -->
                <div class="p-4">
                  <!-- Input de Descrição -->
                  <div class="mb-4">
                    <div class="relative h-10">
                      <input
                        v-model="newOffer.description"
                        type="text"
                        class="w-full h-full px-4 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500"
                        :placeholder="
                          t('KANBAN.FORM.VALUE.OFFER_DESCRIPTION_PLACEHOLDER')
                        "
                      />
                    </div>
                  </div>

                  <!-- Grupo de Inputs de Valor -->
                  <div class="flex items-center h-10 gap-2">
                    <!-- Input de Valor -->
                    <div class="relative flex-1 h-full">
                      <input
                        v-model="newOffer.value"
                        type="text"
                        inputmode="decimal"
                        class="w-full h-full px-4 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 shadow-sm text-left pr-12"
                        :placeholder="t('KANBAN.FORM.VALUE.PLACEHOLDER')"
                        @input="e => formatCurrencyInput(e, 'new')"
                        @blur="e => validateCurrencyInput(e, 'new')"
                      />
                      <div
                        class="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none"
                      >
                        <span
                          class="text-slate-500 dark:text-slate-400 sm:text-sm"
                        >
                          {{ newOffer.currency.symbol }}
                        </span>
                      </div>
                    </div>

                    <!-- Seletor de Moeda -->
                    <div class="relative currency-selector h-full">
                      <button
                        ref="currencyButton"
                        type="button"
                        class="flex items-center h-full gap-2 px-3 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700/50 focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 transition-all min-w-[80px]"
                        @click="() => toggleCurrencySelector('new')"
                      >
                        <span class="font-medium">{{
                          newOffer.currency.code
                        }}</span>
                        <fluent-icon
                          icon="chevron-down"
                          size="12"
                          class="text-slate-400"
                          :class="{
                            'rotate-180': currencySelectorIndex === 'new',
                          }"
                        />
                      </button>

                      <!-- Dropdown do Seletor -->
                      <div
                        v-if="currencySelectorIndex === 'new'"
                        class="fixed right-auto mt-1 w-[120px] py-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg shadow-lg z-[99999]"
                        :style="{
                          top:
                            $refs.currencyButton.getBoundingClientRect()
                              .bottom +
                            4 +
                            'px',
                          left:
                            $refs.currencyButton.getBoundingClientRect().left +
                            'px',
                        }"
                      >
                        <button
                          v-for="currency in currencyOptions"
                          :key="currency.code"
                          type="button"
                          class="flex items-center w-full px-3 py-2 text-sm hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
                          :class="{
                            'text-woot-500 bg-woot-50 dark:bg-woot-900/20':
                              newOffer.currency.code === currency.code,
                            'text-slate-700 dark:text-slate-300':
                              newOffer.currency.code !== currency.code,
                          }"
                          @click="() => selectCurrency(currency, 'new')"
                        >
                          <span class="mr-2">{{ currency.symbol }}</span>
                          {{ currency.code }}
                        </button>
                      </div>
                    </div>

                    <!-- Botão Adicionar -->
                    <button
                      type="button"
                      class="p-2.5 bg-woot-500 hover:bg-woot-600 text-white rounded-lg transition-colors"
                      @click="addOffer"
                    >
                      <fluent-icon icon="add" size="16" />
                    </button>
                  </div>
                </div>

                <!-- Lista de Ofertas -->
                <div v-for="(offer, index) in offers" :key="index" class="p-4">
                  <div class="flex items-center justify-between gap-2">
                    <!-- Descrição e Valor -->
                    <div class="flex items-center gap-2 flex-1">
                      <span class="text-sm text-slate-600 dark:text-slate-400">
                        {{
                          offer.description || t('FORM.VALUE.OFFER_DESCRIPTION')
                        }}
                      </span>
                      <div class="flex items-center gap-1">
                        <span
                          class="text-sm font-medium text-slate-700 dark:text-slate-300"
                        >
                          {{ formatCurrencyValue(offer.value, offer.currency) }}
                        </span>
                        <span
                          class="text-xs text-slate-500 dark:text-slate-400"
                        >
                          {{ offer.currency.code }}
                        </span>
                      </div>
                    </div>

                    <!-- Botão Remover Oferta -->
                    <button
                      class="p-1.5 text-slate-400 hover:text-ruby-500 dark:text-slate-500 dark:hover:text-ruby-400 hover:bg-ruby-50 dark:hover:bg-ruby-900/20 rounded transition-colors"
                      @click="() => removeOffer(index)"
                    >
                      <fluent-icon icon="dismiss" size="16" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Descrição - Ocupa 2/3 -->
          <div class="lg:col-span-2">
            <div
              class="h-full flex flex-col bg-gradient-to-br from-slate-50/50 to-white dark:from-slate-800/50 dark:to-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden"
            >
              <div
                class="p-4 border-b border-slate-200/50 dark:border-slate-700/50"
              >
                <label
                  class="block text-sm font-medium text-slate-600 dark:text-slate-300"
                >
                  {{ t('KANBAN.FORM.DESCRIPTION.LABEL') }}
                </label>
              </div>
              <div class="flex-1 p-4">
                <textarea
                  v-model="form.description"
                  rows="4"
                  class="w-full h-full px-4 py-2.5 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 resize-none shadow-sm"
                  :placeholder="t('KANBAN.FORM.DESCRIPTION.PLACEHOLDER')"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Tab Pipeline -->
      <div v-if="activeTab === 'pipeline'" class="space-y-6">
        <div class="grid grid-cols-2 gap-6">
          <!-- Funil -->
          <div class="space-y-2">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              {{ t('KANBAN.FORM.FUNNEL.LABEL') }}
            </label>
            <FunnelSelector class="w-full" />
          </div>

          <!-- Etapa -->
          <div class="space-y-2">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              {{ t('KANBAN.FORM.STAGE.LABEL') }}
            </label>
            <select
              v-model="form.funnel_stage"
              class="w-full px-4 py-2.5 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500"
              :disabled="!selectedFunnel?.id"
            >
              <option value="" disabled>
                {{ t('KANBAN.FORM.STAGE.PLACEHOLDER') }}
              </option>
              <option
                v-for="stage in availableStages"
                :key="stage.id"
                :value="stage.id"
              >
                {{ stage.name }}
              </option>
            </select>
          </div>
        </div>
      </div>

      <!-- Tab Atribuição -->
      <div v-if="activeTab === 'assignment'" class="space-y-6">
        <div class="flex items-center gap-3 mb-6">
          <div
            class="flex items-center justify-center w-8 h-8 rounded-lg bg-woot-50 dark:bg-woot-900/20"
          >
            <fluent-icon icon="bot" size="18" class="text-woot-500" />
          </div>
          <h4 class="text-base font-medium text-slate-800 dark:text-slate-100">
            {{ t('KANBAN.TABS.ASSIGNMENT') }}
          </h4>
        </div>

        <div class="space-y-4">
          <div class="space-y-1.5">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              {{ t('KANBAN.FORM.PRIORITY.LABEL') }}
            </label>
            <div class="grid grid-cols-5 gap-2">
              <label
                v-for="option in priorityOptions"
                :key="option.id"
                class="relative flex cursor-pointer"
              >
                <input
                  v-model="form.item_details.priority"
                  type="radio"
                  :value="option.id"
                  class="peer sr-only"
                />
                <div
                  class="w-full px-3 py-2 text-xs text-center rounded-lg border transition-colors peer-checked:border-woot-500 peer-checked:bg-woot-50 peer-checked:text-woot-600 dark:peer-checked:bg-woot-900/20 dark:peer-checked:text-woot-400"
                  :class="[
                    option.id === form.item_details.priority
                      ? {
                          'border-slate-200 bg-slate-100 text-slate-600 dark:bg-slate-700/50 dark:text-slate-300':
                            option.id === 'none',
                          'border-ruby-200 bg-ruby-500 text-white dark:bg-ruby-500 dark:text-white':
                            option.id === 'urgent',
                          'border-orange-200 bg-orange-600 text-white dark:bg-orange-600 dark:text-white':
                            option.id === 'high',
                          'border-yellow-200 bg-yellow-500 text-white dark:bg-yellow-500 dark:text-white':
                            option.id === 'medium',
                          'border-green-200 bg-[#22c55e] text-white dark:bg-[#22c55e] dark:text-white':
                            option.id === 'low',
                        }
                      : {
                          'border-slate-200 bg-slate-100 text-slate-500 dark:bg-slate-700/50 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700':
                            option.id === 'none',
                          'border-ruby-200 bg-ruby-100 text-ruby-500 dark:bg-ruby-900/30 dark:text-ruby-400 hover:bg-ruby-200 dark:hover:bg-ruby-900/50':
                            option.id === 'urgent',
                          'border-orange-200 bg-orange-100 text-orange-600 dark:bg-orange-900/30 dark:text-orange-400 hover:bg-orange-200 dark:hover:bg-orange-900/50':
                            option.id === 'high',
                          'border-yellow-200 bg-yellow-100 text-[#996b00] dark:bg-yellow-900/30 dark:text-yellow-600 hover:bg-yellow-200 dark:hover:bg-yellow-900/50':
                            option.id === 'medium',
                          'border-green-200 bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400 hover:bg-green-200 dark:hover:bg-green-900/50':
                            option.id === 'low',
                        },
                  ]"
                >
                  {{ option.name }}
                </div>
              </label>
            </div>
          </div>

          <!-- Agente -->
          <div class="space-y-1.5">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              {{ t('KANBAN.FORM.AGENT.LABEL') }}
            </label>
            <div class="relative">
              <select
                v-model="form.item_details.agent_id"
                class="w-full px-3 py-2 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500"
                :disabled="loadingAgents"
              >
                <option value="">
                  {{ t('KANBAN.FORM.AGENT.PLACEHOLDER') }}
                </option>
                <option
                  v-for="agent in store.getters['agents/getAgents']"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>
              <div
                v-if="loadingAgents"
                class="absolute right-2 top-1/2 transform -translate-y-1/2"
              >
                <span class="loading-spinner" />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Tab Agendamento -->
      <div v-if="activeTab === 'scheduling'" class="space-y-6">
        <div class="flex items-center gap-3 mb-6">
          <div
            class="flex items-center justify-center w-8 h-8 rounded-lg bg-woot-50 dark:bg-woot-900/20"
          >
            <fluent-icon
              icon="calendar-clock"
              size="18"
              class="text-woot-500"
            />
          </div>
          <h4 class="text-base font-medium text-slate-800 dark:text-slate-100">
            {{ t('KANBAN.FORM.SCHEDULING.LABEL') }}
          </h4>
        </div>

        <div class="space-y-4">
          <div class="flex items-center">
            <input
              id="has-scheduling"
              v-model="showScheduling"
              type="checkbox"
              class="w-4 h-4 text-woot-500 border-slate-300 rounded focus:ring-woot-500"
            />
            <label
              for="has-scheduling"
              class="ml-2 text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              {{ t('KANBAN.FORM.SCHEDULING.HAS_SCHEDULING') }}
            </label>
          </div>

          <div v-if="showScheduling" class="space-y-4">
            <div class="flex gap-6">
              <label class="flex items-center">
                <input
                  v-model="schedulingType"
                  type="radio"
                  value="deadline"
                  class="w-4 h-4 text-woot-500 border-slate-300 focus:ring-woot-500"
                />
                <span class="ml-2 text-sm text-slate-700 dark:text-slate-300">
                  {{ t('KANBAN.FORM.SCHEDULING.DEADLINE') }}
                </span>
              </label>
              <label class="flex items-center">
                <input
                  v-model="schedulingType"
                  type="radio"
                  value="schedule"
                  class="w-4 h-4 text-woot-500 border-slate-300 focus:ring-woot-500"
                />
                <span class="ml-2 text-sm text-slate-700 dark:text-slate-300">
                  {{ t('KANBAN.FORM.SCHEDULING.SCHEDULE') }}
                </span>
              </label>
            </div>

            <div v-if="schedulingType === 'schedule'" class="space-y-1.5">
              <label
                class="block text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ t('KANBAN.FORM.SCHEDULING.DATETIME') }}
              </label>
              <input
                v-model="form.item_details.scheduled_at"
                type="datetime-local"
                class="w-full px-3 py-2 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500"
                :min="new Date(Date.now() + 60000).toISOString().slice(0, 16)"
              />
            </div>

            <div v-else class="space-y-1.5">
              <label
                class="block text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ t('KANBAN.FORM.SCHEDULING.DEADLINE_DATE') }}
              </label>
              <input
                v-model="form.item_details.deadline_at"
                type="date"
                class="w-full px-3 py-2 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500"
                :min="new Date(Date.now()).toISOString().slice(0, 10)"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Tab Relacionamentos -->
      <div v-if="activeTab === 'relationships'" class="space-y-6">
        <div class="flex items-center gap-3 mb-6">
          <div
            class="flex items-center justify-center w-8 h-8 rounded-lg bg-woot-50 dark:bg-woot-900/20"
          >
            <fluent-icon icon="attach" size="18" class="text-woot-500" />
          </div>
          <h4 class="text-base font-medium text-slate-800 dark:text-slate-100">
            {{ t('KANBAN.TABS.RELATIONSHIPS') }}
          </h4>
        </div>

        <div class="space-y-4">
          <!-- Conversa -->
          <div class="space-y-3">
            <div class="flex items-center">
              <input
                id="has-conversation"
                v-model="showConversationInput"
                type="checkbox"
                class="w-4 h-4 text-woot-500 border-slate-300 rounded focus:ring-woot-500"
              />
              <label
                for="has-conversation"
                class="ml-2 text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ t('KANBAN.FORM.CONVERSATION.HAS_CONVERSATION') }}
              </label>
            </div>

            <select
              v-if="showConversationInput"
              v-model="form.item_details.conversation_id"
              class="w-full px-3 py-2 text-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500"
              :disabled="loadingConversations"
            >
              <option value="">
                {{ t('KANBAN.FORM.CONVERSATION.PLACEHOLDER') }}
              </option>
              <option
                v-for="conversation in conversations"
                :key="conversation.id"
                :value="conversation.id"
              >
                #{{ conversation.id }} -
                {{
                  conversation.meta.sender.name ||
                  conversation.meta.sender.email
                }}
              </option>
            </select>
          </div>
        </div>
      </div>

      <!-- Tab Campos Personalizados -->
      <div
        v-if="activeTab === 'custom_fields'"
        class="space-y-6"
        @click.prevent.stop
      >
        <div v-if="loadingAttributes" class="flex justify-center py-4">
          <span class="loading-spinner" />
        </div>

        <div v-else-if="customAttributes.length === 0" class="text-center py-4">
          <p class="text-sm text-slate-500">
            {{ t('KANBAN.FORM.CUSTOM_FIELDS.EMPTY') }}
          </p>
        </div>

        <div v-else class="space-y-4" @click.prevent.stop>
          <div
            v-for="attribute in customAttributes"
            :key="attribute.attribute_key"
            class="space-y-2"
            @click.prevent.stop
          >
            <label class="block text-sm font-medium">
              {{ attribute.attribute_display_name }}
            </label>

            <!-- Input para texto -->
            <input
              v-if="attribute.attribute_input_type === 'text'"
              v-model="conversationAttributes[attribute.attribute_key]"
              type="text"
              class="w-full rounded-lg"
              :placeholder="attribute.attribute_description"
              @click.prevent.stop
            />

            <!-- Select para lista -->
            <select
              v-else-if="attribute.attribute_input_type === 'select'"
              v-model="conversationAttributes[attribute.attribute_key]"
              class="w-full rounded-lg"
              @click.prevent.stop
            >
              <option value="">
                {{ t('KANBAN.FORM.CUSTOM_FIELDS.SELECT') }}
              </option>
              <option
                v-for="option in attribute.attribute_values"
                :key="option"
                :value="option"
              >
                {{ option }}
              </option>
            </select>

            <!-- Checkbox -->
            <div
              v-else-if="attribute.attribute_input_type === 'checkbox'"
              @click.prevent.stop
            >
              <label class="flex items-center gap-2">
                <input
                  type="checkbox"
                  v-model="conversationAttributes[attribute.attribute_key]"
                  class="rounded"
                  @click.prevent.stop
                />
                <span class="text-sm">{{
                  attribute.attribute_description
                }}</span>
              </label>
            </div>

            <!-- Número -->
            <input
              v-else-if="attribute.attribute_input_type === 'number'"
              v-model="conversationAttributes[attribute.attribute_key]"
              type="number"
              class="w-full rounded-lg"
              :placeholder="attribute.attribute_description"
              @click.prevent.stop
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Botões -->
    <div class="flex justify-end space-x-2 pt-4 p-3">
      <woot-button
        type="button"
        variant="clear"
        color-scheme="secondary"
        @click="emit('close')"
      >
        {{ t('KANBAN.CANCEL') }}
      </woot-button>
      <woot-button
        type="submit"
        variant="solid"
        color-scheme="primary"
        :loading="loading"
      >
        {{ t('KANBAN.SAVE') }}
      </woot-button>
    </div>
  </form>
</template>

<style lang="scss" scoped>
// Efeito de foco nos inputs
input,
textarea {
  @apply transition-shadow duration-200;

  &:focus {
    @apply shadow-md;
  }
}

// Animação suave do checkbox
input[type='checkbox'] {
  @apply transition-transform duration-200;

  &:checked {
    @apply scale-105;
  }
}

.loading-spinner {
  @apply w-4 h-4 border-2 border-slate-200 border-t-woot-500 rounded-full animate-spin;
}

input[type='date'],
input[type='datetime-local'] {
  &::-webkit-calendar-picker-indicator {
    @apply dark:invert cursor-pointer;
  }
}

input[type='checkbox'],
input[type='radio'] {
  @apply cursor-pointer;
}

select {
  @apply cursor-pointer;
}

label {
  @apply cursor-pointer;
}

// Estilização do scroll
::-webkit-scrollbar {
  @apply w-2;
}

::-webkit-scrollbar-track {
  @apply bg-transparent;
}

::-webkit-scrollbar-thumb {
  @apply bg-slate-300 dark:bg-slate-600 rounded-full;

  &:hover {
    @apply bg-slate-400 dark:bg-slate-500;
  }
}

// Ajuste para o scroll
form {
  @apply min-w-0 w-full transition-all;
}

// Ajuste para os grids responsivos
.grid {
  @apply min-w-0 w-full;
}

// Estilos das tabs
.tabs-container {
  @apply -mx-2;
}

.tab-button {
  @apply relative px-4 py-3 text-sm font-medium transition-colors;
}

.tab-active {
  @apply text-woot-500;

  &::after {
    content: '';
    @apply absolute bottom-0 left-0 right-0 h-0.5 bg-woot-500;
  }
}

.tab-inactive {
  @apply text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300;
}

// Cards com cores diferentes
.info-card {
  @apply relative overflow-hidden flex flex-col gap-1 p-3 rounded-lg transition-all duration-200;

  &:nth-child(1) {
    @apply bg-woot-50 dark:bg-slate-800 border-woot-100 dark:border-woot-700/50;
  }

  &:nth-child(2) {
    @apply bg-green-50 dark:bg-slate-800 border-green-100 dark:border-green-700/50;
  }

  &:nth-child(3) {
    @apply bg-yellow-50 dark:bg-slate-800 border-yellow-100 dark:border-yellow-700/50;
  }

  &:nth-child(4) {
    @apply bg-indigo-50 dark:bg-slate-800 border-indigo-100 dark:border-indigo-700/50;
  }
}
</style>
