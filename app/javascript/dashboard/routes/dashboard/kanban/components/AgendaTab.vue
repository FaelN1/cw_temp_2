<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import KanbanHeader from './KanbanHeader.vue';
import KanbanAPI from '../../../../api/kanban';
import Modal from '../../../../components/Modal.vue';
import KanbanItemForm from './KanbanItemForm.vue';
import KanbanItemDetails from './KanbanItemDetails.vue';
import AgentAPI from '../../../../api/agents';

const { t } = useI18n();
const store = useStore();
const isLoading = ref(false);
const error = ref(null);
const items = ref([]);
const agents = ref({});
const searchQuery = ref('');
const activeFilters = ref(null);
const filteredResults = ref({ total: 0, stages: {} });
const currentMonth = ref(new Date());
const selectedDate = ref(new Date());
const showAddModal = ref(false);
const showEventDetails = ref(false);
const selectedEvent = ref(null);
const viewMode = ref('month'); // month, week, day

// Refs para controle do popover
const showMonthPicker = ref(false);
const monthPickerAnchor = ref(null);

// Array com os nomes dos meses
const monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

// Computed para o ano atual e anos disponíveis para seleção
const currentYear = computed(() => currentMonth.value.getFullYear());
const yearOptions = computed(() => {
  const currentYearNum = new Date().getFullYear();
  // Gerar array com 100 anos para trás e 50 anos para frente
  return Array.from({ length: 151 }, (_, i) => currentYearNum - 100 + i);
});

// Adicionar computed para o mês atual
const currentMonthIndex = computed(() => currentMonth.value.getMonth());

// Função para mudar o mês e ano diretamente
const setMonthAndYear = (month, year) => {
  const newDate = new Date(year, month, 1);
  currentMonth.value = newDate;
  selectedDate.value = newDate;
  showMonthPicker.value = false;
};

// Refs para controle do modal de detalhes
const showItemDetails = ref(false);
const selectedItem = ref(null);

// Adicionar ref para controlar o estado de drag & drop
const dragOverCell = ref(null);

// Adicionar ref para controlar o estado de expansão
const isRecentItemsExpanded = ref(true);

// Adicionar nova ref para controlar a data selecionada no mini calendário
const selectedMiniDate = ref(new Date());

const showEditModal = ref(false);
const selectedItemToEdit = ref(null);

const props = defineProps({
  currentView: {
    type: String,
    default: 'agenda',
  },
  columns: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['switch-view']);

// Computed para dias do mês atual
const daysInMonth = computed(() => {
  const year = currentMonth.value.getFullYear();
  const month = currentMonth.value.getMonth();
  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);
  const days = [];

  // Adicionar dias do mês anterior para completar a primeira semana
  const firstDayOfWeek = firstDay.getDay();
  for (let i = firstDayOfWeek - 1; i >= 0; i--) {
    const date = new Date(year, month, -i);
    days.push({
      date,
      isCurrentMonth: false,
      events: getEventsForDate(date),
    });
  }

  // Adicionar dias do mês atual
  for (let date = 1; date <= lastDay.getDate(); date++) {
    const currentDate = new Date(year, month, date);
    days.push({
      date: currentDate,
      isCurrentMonth: true,
      events: getEventsForDate(currentDate),
    });
  }

  // Adicionar dias do próximo mês para completar a última semana
  const remainingDays = 42 - days.length; // 6 semanas * 7 dias = 42
  for (let i = 1; i <= remainingDays; i++) {
    const date = new Date(year, month + 1, i);
    days.push({
      date,
      isCurrentMonth: false,
      events: getEventsForDate(date),
    });
  }

  return days;
});

// Adicionar computed para dias baseado no modo de visualização
const visibleDays = computed(() => {
  if (viewMode.value === 'week') {
    return getWeekDays();
  }
  return daysInMonth.value;
});

// Função para obter os dias da semana atual
const getWeekDays = () => {
  const today = selectedDate.value || new Date();
  const start = new Date(today);
  start.setDate(start.getDate() - start.getDay()); // Começa no domingo

  const days = [];
  for (let i = 0; i < 7; i++) {
    const date = new Date(start);
    date.setDate(start.getDate() + i);
    days.push({
      date,
      isCurrentMonth: date.getMonth() === currentMonth.value.getMonth(),
      events: getEventsForDate(date),
    });
  }
  return days;
};

// Atualizar o computed weeks para usar visibleDays
const weeks = computed(() => {
  const days =
    viewMode.value === 'week' ? visibleDays.value : daysInMonth.value;
  const weeks = [];
  for (let i = 0; i < days.length; i += 7) {
    weeks.push(days.slice(i, i + 7));
  }
  return weeks;
});

// Computed para nomes dos dias da semana
const weekDays = computed(() => {
  const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
  return days;
});

// Atualizar a função getEventsForDate para usar o horário local
const getEventsForDate = date => {
  return items.value.filter(item => {
    const itemDate =
      item.item_details?.scheduled_at || item.item_details?.deadline_at;
    if (!itemDate) return false;

    const [datePart] = itemDate.split('T');
    const compareDate = date.toISOString().split('T')[0];

    return datePart === compareDate;
  });
};

// Adicionar função para navegar entre semanas
const changeWeek = direction => {
  const newDate = new Date(selectedDate.value);
  newDate.setDate(newDate.getDate() + direction * 7);
  selectedDate.value = newDate;
  currentMonth.value = new Date(newDate); // Atualiza o mês se necessário
};

// Atualizar a função de mudança de mês para considerar o modo
const changeMonth = direction => {
  if (viewMode.value === 'week') {
    changeWeek(direction * 4); // Aproximadamente um mês
    return;
  }

  const newMonth = new Date(currentMonth.value);
  newMonth.setMonth(newMonth.getMonth() + direction);
  currentMonth.value = newMonth;
  selectedDate.value = newMonth;
};

// Atualizar a função formatDate para aceitar opções
const formatDate = (date, options = { month: 'long', year: 'numeric' }) => {
  return new Intl.DateTimeFormat('pt-BR', {
    ...options,
  }).format(date);
};

// Função para verificar se é hoje
const isToday = date => {
  const today = new Date();
  return (
    date.getDate() === today.getDate() &&
    date.getMonth() === today.getMonth() &&
    date.getFullYear() === today.getFullYear()
  );
};

// Adicionar o computed para eventos do dia
const todayEvents = computed(() => {
  const today = new Date();
  return items.value
    .filter(item => {
      const itemDate =
        item.item_details?.scheduling_type === 'deadline'
          ? item.item_details?.deadline_at
          : item.item_details?.scheduled_at;

      if (!itemDate) return false;

      const eventDate = new Date(itemDate);

      return (
        eventDate.getUTCFullYear() === today.getFullYear() &&
        eventDate.getUTCMonth() === today.getMonth() &&
        eventDate.getUTCDate() === today.getDate()
      );
    })
    .sort((a, b) => {
      const dateA = new Date(
        a.item_details?.scheduling_type === 'deadline'
          ? a.item_details?.deadline_at
          : a.item_details?.scheduled_at
      );
      const dateB = new Date(
        b.item_details?.scheduling_type === 'deadline'
          ? b.item_details?.deadline_at
          : b.item_details?.scheduled_at
      );
      return dateA - dateB;
    });
});

// Atualizar a função para converter UTC para horário local
const toLocalTime = date => {
  if (!date) return null;
  try {
    const utcDate = new Date(date);
    // Extrair apenas o horário no formato HH:mm
    return `${String(utcDate.getHours()).padStart(2, '0')}:${String(
      utcDate.getMinutes()
    ).padStart(2, '0')}`;
  } catch (error) {
    console.error('Erro ao converter data:', error);
    return null;
  }
};

// Simplificar para mostrar apenas o título do evento
const formatEventTime = date => {
  if (!date) return '';
  return ''; // Não exibir horário
};

// Simplificar o posicionamento para usar horário local
const getEventStyle = (date, event) => {
  const eventTime =
    event.item_details?.scheduled_at || event.item_details?.deadline_at;
  if (!eventTime) return {};

  let hours, minutes;

  // Se a data vier sem timezone (formato YYYY-MM-DDTHH:mm)
  if (eventTime.length === 16) {
    const [datePart, timePart] = eventTime.split('T');
    [hours, minutes] = timePart.split(':').map(n => parseInt(n, 10));
  } else {
    const d = new Date(eventTime);
    hours = d.getHours();
    minutes = d.getMinutes();
  }

  // Calcular posição como porcentagem do dia
  const percentageOfDay = ((hours * 60 + minutes) / (24 * 60)) * 100;

  return {
    position: 'absolute',
    top: `${percentageOfDay}%`,
    left: '0',
    right: '0',
    height: '30px',
    zIndex: '1',
  };
};

// Atualizar o computed recentItems
const recentItems = computed(() => {
  // Pegar os 10 itens mais recentes, independente de terem ou não agendamento
  return items.value
    .filter(item => {
      // Filtrar apenas itens que não têm prazo/agendamento
      const hasScheduling =
        item.item_details?.scheduled_at || item.item_details?.deadline_at;
      return !hasScheduling;
    })
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
    .slice(0, 10);
});

// Adicionar computed para formatar valor
const formatValue = value => {
  if (!value) return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value);
};

// Adicionar função para buscar dados do agente
const fetchAgentDetails = async agentId => {
  if (!agentId) return null;
  if (agents.value[agentId]) return agents.value[agentId];

  try {
    // Buscar todos os agentes se ainda não tivermos buscado
    if (Object.keys(agents.value).length === 0) {
      const { data } = await AgentAPI.get();
      // Mapear os agentes por ID para acesso mais rápido
      data.forEach(agent => {
        agents.value[agent.id] = agent;
      });
    }

    return agents.value[agentId] || null;
  } catch (error) {
    console.error('Erro ao carregar agente:', error);
    return null;
  }
};

// Atualizar a função fetchKanbanItems
const fetchKanbanItems = async ({ showLoading = true } = {}) => {
  try {
    if (showLoading) {
      isLoading.value = true;
    }

    // Carregar todos os agentes primeiro
    if (Object.keys(agents.value).length === 0) {
      const { data } = await AgentAPI.get();
      data.forEach(agent => {
        agents.value[agent.id] = agent;
      });
    }

    const response = await KanbanAPI.getItems();

    // Mapear os itens e buscar dados dos agentes
    const itemsWithAgents = await Promise.all(
      response.data.map(async item => {
        const agentId = item.item_details?.agent_id;
        const agent = agentId ? agents.value[agentId] : null;

        return {
          id: item.id,
          title: item.item_details?.title || '',
          description: item.item_details?.description || '',
          priority: item.item_details?.priority || 'none',
          funnel_id: item.funnel_id,
          funnel_stage: item.funnel_stage,
          position: item.position,
          item_details: {
            ...item.item_details,
            _agent: agent, // Adicionar dados do agente ao item_details
          },
          stageName:
            props.columns.find(col => col.id === item.funnel_stage)?.title ||
            '',
          stageColor:
            props.columns.find(col => col.id === item.funnel_stage)?.color ||
            '#64748B',
          created_at: item.created_at,
          custom_attributes: item.custom_attributes || {},
        };
      })
    );

    items.value = itemsWithAgents;
  } catch (e) {
    console.error('Erro ao carregar itens:', e);
    error.value = t('KANBAN.ERRORS.FETCH_ITEMS');
  } finally {
    isLoading.value = false;
  }
};

// Handlers
const handleViewChange = view => {
  emit('switch-view', view);
};

const handleDateClick = (date, events) => {
  selectedDate.value = date;
  showAddModal.value = true;
};

const handleFilter = filters => {
  activeFilters.value = filters;
};

const handleSearch = query => {
  searchQuery.value = query;
};

const handleItemCreated = async item => {
  if (!item) return;
  showAddModal.value = false;
  await fetchKanbanItems({ showLoading: false });
};

// Função para abrir detalhes do item
const handleEventClick = event => {
  selectedItem.value = event;
  showItemDetails.value = true;
};

// Função para fechar detalhes do item
const handleCloseDetails = () => {
  showItemDetails.value = false;
  selectedItem.value = null;
};

// Atualizar a função handleCardDrop para armazenar datas de remarcação
const handleCardDrop = async (itemId, date, isReschedule = false) => {
  try {
    const item = items.value.find(i => i.id === itemId);
    if (!item) return;

    // Obter a data atual do item antes da remarcação
    const currentDate =
      item.item_details?.scheduling_type === 'deadline'
        ? item.item_details?.deadline_at
        : item.item_details?.scheduled_at;

    // Criar uma cópia do item_details para não modificar o original
    const updatedItemDetails = {
      ...item.item_details,
      scheduling_type: 'deadline',
      deadline_at: new Date(date).toISOString().split('T')[0],
      rescheduled: isReschedule,
      rescheduling_history: isReschedule
        ? [
            ...(item.item_details.rescheduling_history || []),
            {
              from_date: currentDate,
              to_date: new Date(date).toISOString().split('T')[0],
              changed_at: new Date().toISOString(),
            },
          ]
        : [],
    };

    const payload = {
      funnel_id: item.funnel_id,
      funnel_stage: item.funnel_stage,
      position: item.position,
      item_details: updatedItemDetails,
      custom_attributes: item.custom_attributes || {},
    };

    await KanbanAPI.updateItem(itemId, payload);
    await fetchKanbanItems();
  } catch (error) {
    console.error('Erro ao definir prazo:', error);
  }
};

// Atualizar as funções de drag & drop
const allowDrop = (e, date) => {
  e.preventDefault();
  dragOverCell.value = date;
};

const handleDragLeave = () => {
  dragOverCell.value = null;
};

const handleDrop = async (e, date) => {
  e.preventDefault();
  const itemId = parseInt(e.dataTransfer.getData('itemId'), 10);
  const isReschedule = e.dataTransfer.getData('isReschedule') === 'true';
  if (!itemId) return;

  dragOverCell.value = null;
  await handleCardDrop(itemId, date, isReschedule);
};

// Adicionar função para alternar expansão
const toggleRecentItems = () => {
  isRecentItemsExpanded.value = !isRecentItemsExpanded.value;
};

// Adicione esta função para lidar com a edição
const handleItemEdit = item => {
  selectedItemToEdit.value = {
    ...item,
    funnel_stage:
      item.funnel_stage ||
      store.getters['funnel/getSelectedFunnel']?.default_stage,
  };
  showEditModal.value = true;
};

// Adicione esta função para lidar com o item atualizado
const handleItemUpdated = async item => {
  showEditModal.value = false;
  selectedItemToEdit.value = null;
  showItemDetails.value = false;
  await fetchKanbanItems({ showLoading: false });
};

// Lifecycle hooks
onMounted(async () => {
  await fetchKanbanItems();
});

// Watch para atualizar quando o funil mudar
watch(
  () => store.getters['funnel/getSelectedFunnel'],
  async () => {
    await fetchKanbanItems();
  }
);

// Adicionar watch para o viewMode
watch(viewMode, newMode => {
  if (newMode === 'week') {
    selectedDate.value = new Date(); // Reset para a semana atual
  }
});

// Computed para eventos do mês atual
const currentMonthEvents = computed(() => {
  return items.value.filter(item => {
    const itemDate =
      item.item_details?.scheduled_at || item.item_details?.deadline_at;
    if (!itemDate) return false;

    const date = new Date(itemDate);
    return (
      date.getMonth() === currentMonth.value.getMonth() &&
      date.getFullYear() === currentMonth.value.getFullYear()
    );
  });
});

// Computed para eventos remarcados
const rescheduledEvents = computed(() => {
  return items.value.filter(item => item.item_details?.rescheduled);
});

// Computed para eventos pendentes (sem data definida)
const pendingEvents = computed(() => {
  return items.value.filter(item => {
    return !item.item_details?.scheduled_at && !item.item_details?.deadline_at;
  });
});

// Adicionar computed para eventos do dia selecionado
const selectedDayEvents = computed(() => {
  return items.value
    .filter(item => {
      const itemDate =
        item.item_details?.scheduling_type === 'deadline'
          ? item.item_details?.deadline_at
          : item.item_details?.scheduled_at;

      if (!itemDate) return false;

      const eventDate = new Date(itemDate);
      return (
        eventDate.getUTCFullYear() === selectedMiniDate.value.getFullYear() &&
        eventDate.getUTCMonth() === selectedMiniDate.value.getMonth() &&
        eventDate.getUTCDate() === selectedMiniDate.value.getDate()
      );
    })
    .sort((a, b) => {
      const dateA = new Date(
        a.item_details?.scheduled_at || a.item_details?.deadline_at
      );
      const dateB = new Date(
        b.item_details?.scheduled_at || b.item_details?.deadline_at
      );
      return dateA - dateB;
    });
});

// Função auxiliar para comparar se duas datas são o mesmo dia
const isSameDay = (date1, date2) => {
  return (
    date1.getFullYear() === date2.getFullYear() &&
    date1.getMonth() === date2.getMonth() &&
    date1.getDate() === date2.getDate()
  );
};

// Add new computed for time-slotted events
const getTimeSlottedEvents = computed(() => {
  if (viewMode.value !== 'week') return {};

  const eventsByDayAndTime = {};

  visibleDays.value.forEach(day => {
    const dayKey = day.date.toISOString().split('T')[0];
    eventsByDayAndTime[dayKey] = {};

    day.events.forEach(event => {
      // Get event time from scheduled_at or deadline_at
      const eventTime =
        event.item_details?.scheduled_at || event.item_details?.deadline_at;
      if (!eventTime) return;

      const eventDate = new Date(eventTime);
      const hour = eventDate.getHours();
      const minutes = eventDate.getMinutes();

      // Create time slot key (HH:MM)
      const timeKey = `${hour.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;

      if (!eventsByDayAndTime[dayKey][timeKey]) {
        eventsByDayAndTime[dayKey][timeKey] = [];
      }

      eventsByDayAndTime[dayKey][timeKey].push(event);
    });
  });

  return eventsByDayAndTime;
});
</script>

<template>
  <div class="flex flex-col h-full bg-white dark:bg-slate-900">
    <KanbanHeader
      :current-view="currentView"
      :search-results="filteredResults"
      :active-filters="activeFilters"
      :columns="columns"
      @switch-view="handleViewChange"
      @filter="handleFilter"
      @search="handleSearch"
    />

    <div class="flex flex-1 min-h-0 flex-col">
      <div class="flex flex-1 min-h-0">
        <!-- Mini Calendar Sidebar -->
        <div
          class="w-[280px] border-r border-slate-200 dark:border-slate-700 flex flex-col mini-calendar-section overflow-hidden"
        >
          <div class="p-4 flex-shrink-0 flex flex-col h-full">
            <!-- Mini Calendar Header -->
            <div class="flex items-center justify-between mb-4">
              <span
                ref="monthPickerAnchor"
                class="text-sm font-medium text-slate-600 dark:text-slate-300 cursor-pointer hover:text-woot-500 dark:hover:text-woot-400"
                @click="showMonthPicker = true"
              >
                {{ formatDate(currentMonth) }}
              </span>

              <!-- Month Picker Popover -->
              <Modal
                v-if="showMonthPicker"
                v-model:show="showMonthPicker"
                :on-close="() => (showMonthPicker = false)"
                size="tiny"
                :anchor="monthPickerAnchor"
              >
                <div class="p-4">
                  <!-- Seletor de Ano -->
                  <div class="mb-4">
                    <label
                      class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
                    >
                      {{ t('KANBAN.YEAR') }}
                    </label>
                    <div class="relative">
                      <select
                        v-model="currentYear"
                        class="w-full rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm py-2 px-3 appearance-none cursor-pointer hover:border-woot-500 dark:hover:border-woot-400 focus:ring-2 focus:ring-woot-500 dark:focus:ring-woot-400"
                      >
                        <option
                          v-for="year in yearOptions"
                          :key="year"
                          :value="year"
                        >
                          {{ year }}
                        </option>
                      </select>
                      <div
                        class="absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none text-slate-400"
                      >
                        <fluent-icon icon="chevron-down" size="12" />
                      </div>
                    </div>
                  </div>

                  <!-- Grid de Meses -->
                  <div class="grid grid-cols-3 gap-2">
                    <button
                      v-for="(month, index) in monthNames"
                      :key="month"
                      class="relative px-3 py-2 text-sm rounded-lg text-center border transition-all duration-200"
                      :class="{
                        'bg-woot-50 border-woot-500 text-woot-600 dark:bg-woot-900/20 dark:border-woot-400 dark:text-woot-400':
                          currentMonthIndex === index,
                        'border-slate-200 dark:border-slate-700 hover:border-woot-500 dark:hover:border-woot-400 hover:bg-slate-50 dark:hover:bg-slate-800/50':
                          currentMonthIndex !== index,
                      }"
                      @click="setMonthAndYear(index, currentYear)"
                    >
                      {{ month }}
                    </button>
                  </div>
                </div>
              </Modal>

              <div class="flex gap-1">
                <woot-button
                  variant="clear"
                  size="small"
                  @click="changeMonth(-1)"
                >
                  <fluent-icon icon="chevron-left" size="12" />
                </woot-button>
                <woot-button
                  variant="clear"
                  size="small"
                  @click="changeMonth(1)"
                >
                  <fluent-icon icon="chevron-right" size="12" />
                </woot-button>
              </div>
            </div>

            <!-- Mini Calendar Grid -->
            <div class="mini-calendar mb-6 flex-shrink-0">
              <!-- Mini Week Days -->
              <div class="grid grid-cols-7 mb-2">
                <div
                  v-for="day in weekDays"
                  :key="day"
                  class="text-[11px] font-medium text-slate-400 text-center py-1"
                >
                  {{ day.charAt(0) }}
                </div>
              </div>

              <!-- Mini Days Grid -->
              <div class="grid grid-cols-7 gap-2">
                <div
                  v-for="day in daysInMonth"
                  :key="day.date"
                  class="aspect-square flex items-center justify-center text-sm rounded-full cursor-pointer"
                  :class="{
                    'bg-slate-100 dark:bg-slate-800': !day.isCurrentMonth,
                    'bg-white dark:bg-slate-900': day.isCurrentMonth,
                    'text-slate-400': !day.isCurrentMonth,
                    'text-slate-900 dark:text-slate-100': day.isCurrentMonth,
                    'bg-woot-500 text-white':
                      isToday(day.date) && !day.events.length,
                    'ring-2 ring-woot-500': isSameDay(
                      day.date,
                      selectedMiniDate
                    ),
                    relative: day.events.length > 0,
                  }"
                  @click="selectedMiniDate = day.date"
                >
                  {{ day.date.getDate() }}
                  <!-- Indicador de eventos -->
                  <div
                    v-if="day.events.length > 0"
                    class="absolute -bottom-1 left-1/2 -translate-x-1/2 w-1.5 h-1.5 rounded-full bg-woot-500"
                  />
                </div>
              </div>
            </div>

            <!-- Today's Events -->
            <div class="today-events-section flex-1 flex flex-col min-h-0">
              <h3
                class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-4"
              >
                {{
                  isSameDay(selectedMiniDate, new Date())
                    ? t('KANBAN.AGENDA.TODAY_EVENTS')
                    : formatDate(selectedMiniDate, {
                        day: 'numeric',
                        month: 'long',
                      })
                }}
              </h3>
              <div class="events-list flex-1 overflow-y-auto space-y-3 pr-2">
                <div v-if="selectedDayEvents.length > 0" class="space-y-3">
                  <div
                    v-for="event in selectedDayEvents"
                    :key="event.id"
                    class="p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer border border-slate-200 dark:border-slate-700"
                    draggable="true"
                    @dragstart="
                      e => {
                        e.dataTransfer.setData('itemId', event.id);
                        e.dataTransfer.setData('isReschedule', 'true');
                      }
                    "
                    @click="handleEventClick(event)"
                  >
                    <!-- Cabeçalho do Evento -->
                    <div class="flex items-center justify-between mb-2">
                      <div class="flex items-center gap-2">
                        <div
                          class="w-2 h-2 rounded-full"
                          :style="{ backgroundColor: event.stageColor }"
                        />
                        <h4
                          class="text-sm font-medium text-slate-800 dark:text-slate-200"
                        >
                          {{ event.title }}
                        </h4>
                        <span
                          v-if="event.item_details?.rescheduled"
                          class="px-1.5 py-0.5 text-[10px] font-medium bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-100 rounded"
                        >
                          {{ t('KANBAN.AGENDA.RESCHEDULED') }}
                        </span>
                      </div>
                      <span
                        class="px-2 py-0.5 text-xs rounded-full"
                        :style="{
                          backgroundColor: event.stageColor + '20',
                          color: event.stageColor,
                        }"
                      >
                        {{ event.stageName }}
                      </span>
                    </div>

                    <!-- Informações do Evento -->
                    <div class="grid grid-cols-2 gap-4 text-xs">
                      <!-- Coluna 1 -->
                      <div class="space-y-1">
                        <!-- Horário -->
                        <div
                          class="flex items-center gap-1 text-slate-600 dark:text-slate-300"
                        >
                          <fluent-icon
                            :icon="
                              event.item_details?.scheduling_type === 'deadline'
                                ? 'alarm'
                                : 'book'
                            "
                            size="12"
                          />
                          {{
                            formatEventTime(
                              event.item_details?.scheduled_at ||
                                event.item_details?.deadline_at
                            )
                          }}
                        </div>

                        <!-- Agente -->
                        <div
                          v-if="event.item_details?.agent_id"
                          class="flex items-center gap-1"
                        >
                          <fluent-icon
                            icon="captain"
                            size="12"
                            class="text-slate-400"
                          />
                          <span class="text-slate-600 dark:text-slate-300">
                            {{
                              event.item_details._agent?.name ||
                              t('KANBAN.AGENDA.LOADING_AGENT')
                            }}
                          </span>
                        </div>

                        <!-- Valor -->
                        <div
                          v-if="event.item_details?.value"
                          class="flex items-center gap-1"
                        >
                          <fluent-icon
                            icon="text-copy"
                            size="12"
                            class="text-slate-400"
                          />
                          <span class="text-slate-600 dark:text-slate-300">
                            {{ formatValue(event.item_details.value) }}
                          </span>
                        </div>
                      </div>

                      <!-- Coluna 2 -->
                      <div class="space-y-1">
                        <!-- Prioridade -->
                        <div class="flex items-center gap-1">
                          <fluent-icon
                            icon="alert"
                            size="12"
                            class="text-slate-400"
                          />
                          <span
                            :class="{
                              'text-ruby-600 dark:text-ruby-400':
                                event.priority === 'high',
                              'text-yellow-600 dark:text-yellow-400':
                                event.priority === 'medium',
                              'text-green-600 dark:text-green-400':
                                event.priority === 'low',
                              'text-slate-600 dark:text-slate-300':
                                event.priority === 'none',
                            }"
                          >
                            {{
                              t(
                                `KANBAN.PRIORITY_LABELS.${(event.priority || 'none').toUpperCase()}`
                              )
                            }}
                          </span>
                        </div>

                        <!-- Conversa -->
                        <div
                          v-if="event.item_details?.conversation_id"
                          class="flex items-center gap-1"
                        >
                          <fluent-icon
                            icon="bot"
                            size="12"
                            class="text-slate-400"
                          />
                          <span class="text-slate-600 dark:text-slate-300">
                            #{{ event.item_details.conversation_id }}
                          </span>
                        </div>

                        <!-- Data Original (se remarcado) -->
                        <div
                          v-if="event.item_details?.previous_date"
                          class="flex items-center gap-1 text-slate-400"
                        >
                          <fluent-icon icon="history" size="12" />
                          {{
                            new Date(
                              event.item_details.previous_date
                            ).toLocaleDateString()
                          }}
                        </div>
                      </div>
                    </div>

                    <!-- Dica de arraste -->
                    <div
                      class="mt-2 flex items-center justify-end gap-1 text-xs text-slate-400"
                    >
                      <fluent-icon icon="automation" size="12" />
                      {{ t('KANBAN.AGENDA.ACTIONS.DRAG_TO_RESCHEDULE') }}
                    </div>
                  </div>
                </div>
                <div
                  v-else
                  class="text-sm text-slate-500 dark:text-slate-400 text-center py-4"
                >
                  {{ t('KANBAN.AGENDA.NO_EVENTS_TODAY') }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Main Calendar -->
        <div class="flex-1 flex flex-col min-h-0">
          <!-- Main Calendar Header -->
          <div class="flex-shrink-0 bg-white dark:bg-slate-900 z-10">
            <div class="flex items-center justify-between px-6 py-4">
              <h2
                class="text-xl font-semibold text-slate-800 dark:text-slate-200"
              >
                {{
                  formatDate(viewMode === 'week' ? selectedDate : currentMonth)
                }}
              </h2>
              <div class="flex items-center gap-2">
                <woot-button
                  variant="clear"
                  size="small"
                  @click="
                    selectedDate = new Date();
                    currentMonth = new Date();
                  "
                >
                  {{ t('KANBAN.AGENDA.VIEW_MODES.TODAY') }}
                </woot-button>
                <div class="flex border rounded-lg overflow-hidden">
                  <woot-button
                    variant="clear"
                    size="small"
                    class="px-3 py-1.5 border-r"
                    :class="{
                      'bg-slate-100 dark:bg-slate-800': viewMode === 'month',
                    }"
                    @click="viewMode = 'month'"
                  >
                    {{ t('KANBAN.AGENDA.VIEW_MODES.MONTH') }}
                  </woot-button>
                  <woot-button
                    variant="clear"
                    size="small"
                    class="px-3 py-1.5"
                    :class="{
                      'bg-slate-100 dark:bg-slate-800': viewMode === 'week',
                    }"
                    @click="viewMode = 'week'"
                  >
                    {{ t('KANBAN.AGENDA.VIEW_MODES.WEEK') }}
                  </woot-button>
                </div>
              </div>
            </div>

            <!-- Week Days Header -->
            <div
              class="grid grid-cols-7 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50"
            >
              <div
                v-for="day in weekDays"
                :key="day"
                class="py-2.5 text-xs font-medium text-slate-600 dark:text-slate-400 text-center border-r last:border-r-0 border-slate-200 dark:border-slate-700"
              >
                {{ day }}
              </div>
            </div>
          </div>

          <!-- Calendar Grid -->
          <div
            class="calendar-grid flex-1 overflow-y-auto"
            :data-view-mode="viewMode"
          >
            <div
              v-for="week in weeks"
              :key="week[0].date"
              class="grid grid-cols-7"
            >
              <div
                v-for="day in week"
                :key="day.date"
                class="calendar-day relative p-2 last:border-r-0"
                :class="{
                  'bg-slate-50 dark:bg-slate-800/50': !day.isCurrentMonth,
                  'bg-white dark:bg-slate-800': day.isCurrentMonth,
                  today: isToday(day.date),
                  'h-full': viewMode === 'week',
                  'flex flex-col h-full': viewMode === 'week',
                }"
                @click="handleDateClick(day.date, day.events)"
                @dragover="e => allowDrop(e, day.date)"
                @dragleave="handleDragLeave"
                @drop="e => handleDrop(e, day.date)"
              >
                <div class="h-full flex flex-col">
                  <span
                    class="text-sm mb-1"
                    :class="{
                      'text-slate-400 dark:text-slate-600': !day.isCurrentMonth,
                      'text-slate-900 dark:text-slate-100': day.isCurrentMonth,
                      'bg-woot-500 text-white rounded-full w-6 h-6 flex items-center justify-center':
                        isToday(day.date),
                    }"
                  >
                    {{ day.date.getDate() }}
                  </span>

                  <!-- Time-slotted events for week view -->
                  <template v-if="viewMode === 'week'">
                    <div class="day-events-container">
                      <div
                        v-for="event in day.events"
                        :key="event.id"
                        class="event-item text-xs p-1 rounded truncate cursor-pointer hover:opacity-90 mb-1"
                        :style="{
                          backgroundColor: event.stageColor + '20',
                          color: event.stageColor,
                          borderLeft: `2px solid ${event.stageColor}`,
                        }"
                        @click.stop="handleEventClick(event)"
                      >
                        <div class="flex items-center gap-1">
                          <fluent-icon
                            :icon="
                              event.item_details?.scheduling_type === 'deadline'
                                ? 'alarm'
                                : 'book'
                            "
                            size="12"
                          />
                          <span class="truncate">{{ event.title }}</span>
                        </div>
                      </div>
                    </div>
                  </template>

                  <!-- Regular events for month view -->
                  <template v-else>
                    <!-- Events -->
                    <div class="day-events-container">
                      <div
                        v-for="event in day.events.slice(0, 3)"
                        :key="event.id"
                        class="event-item text-xs p-1 rounded truncate cursor-pointer hover:opacity-90"
                        :class="{
                          'border-l-2': event.scheduling_type === 'deadline',
                        }"
                        :style="{
                          backgroundColor: event.stageColor + '20',
                          color: event.stageColor,
                          borderColor:
                            event.scheduling_type === 'deadline'
                              ? event.stageColor
                              : 'transparent',
                        }"
                        @click.stop="handleEventClick(event)"
                      >
                        <div class="flex items-center gap-1">
                          <fluent-icon
                            :icon="
                              event.scheduling_type === 'deadline'
                                ? 'alarm'
                                : 'book'
                            "
                            size="12"
                            class="flex-shrink-0"
                          />
                          <span class="truncate">{{ event.title }}</span>
                        </div>
                      </div>
                      <div
                        v-if="day.events.length > 3"
                        class="text-xs text-slate-500 dark:text-slate-400 pl-1"
                      >
                        +{{ day.events.length - 3 }} mais
                      </div>
                    </div>
                  </template>
                </div>
              </div>
            </div>
          </div>

          <!-- Resumo do Mês -->
          <div
            class="flex-shrink-0 border-t border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 month-summary"
          >
            <div class="flex items-center gap-6 px-6 py-3">
              <!-- Total de Eventos -->
              <div class="flex items-center gap-2">
                <span class="text-sm text-slate-600 dark:text-slate-400">
                  {{ t('KANBAN.AGENDA.TOTAL_EVENTS') }}:
                </span>
                <span
                  class="text-sm font-medium text-slate-900 dark:text-slate-100"
                >
                  {{ items.length }}
                </span>
              </div>

              <!-- Eventos do Mês -->
              <div class="flex items-center gap-2">
                <span class="text-sm text-woot-600 dark:text-woot-400">
                  {{ t('KANBAN.AGENDA.MONTH_EVENTS') }}:
                </span>
                <span
                  class="text-sm font-medium text-woot-600 dark:text-woot-400"
                >
                  {{ currentMonthEvents.length }}
                </span>
              </div>

              <!-- Eventos Remarcados -->
              <div class="flex items-center gap-2">
                <span class="text-sm text-yellow-600 dark:text-yellow-400">
                  {{ t('KANBAN.AGENDA.RESCHEDULED_EVENTS') }}:
                </span>
                <span
                  class="text-sm font-medium text-yellow-600 dark:text-yellow-400"
                >
                  {{ rescheduledEvents.length }}
                </span>
              </div>

              <!-- Eventos Pendentes -->
              <div class="flex items-center gap-2">
                <span class="text-sm text-ruby-600 dark:text-ruby-400">
                  {{ t('KANBAN.AGENDA.NO_DATE_ITEMS') }}:
                </span>
                <span
                  class="text-sm font-medium text-ruby-600 dark:text-ruby-400"
                >
                  {{ pendingEvents.length }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Seção de Itens Recentes -->
      <div
        class="border-t border-slate-200 dark:border-slate-700 mt-auto recent-items-section"
      >
        <div
          class="flex items-center justify-between p-4 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800/50"
          @click="toggleRecentItems"
        >
          <div class="flex items-center gap-2">
            <fluent-icon
              :icon="isRecentItemsExpanded ? 'chevron-down' : 'chevron-right'"
              size="16"
              class="text-slate-400"
            />
            <h3 class="text-sm font-medium text-slate-900 dark:text-slate-100">
              {{ t('KANBAN.AGENDA.RECENT_ITEMS') }}
            </h3>
            <span class="text-xs text-slate-500">
              ({{ recentItems.length }})
            </span>
          </div>
          <span class="text-xs text-slate-500">
            {{ t('KANBAN.AGENDA.DRAG_TO_SCHEDULE') }}
          </span>
        </div>

        <!-- Cards Container com transição -->
        <transition
          enter-active-class="transition-all duration-300 ease-out"
          leave-active-class="transition-all duration-300 ease-in"
          enter-from-class="opacity-0 max-h-0"
          enter-to-class="opacity-100 max-h-[400px]"
          leave-from-class="opacity-100 max-h-[400px]"
          leave-to-class="opacity-0 max-h-0"
        >
          <div v-show="isRecentItemsExpanded" class="overflow-hidden">
            <div class="overflow-x-auto p-4 pt-0">
              <div class="flex gap-4">
                <div
                  v-for="item in recentItems"
                  :key="item.id"
                  class="flex-shrink-0 w-[400px] p-2 bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 shadow-sm hover:shadow-md transition-shadow cursor-move"
                  draggable="true"
                  @dragstart="
                    e => {
                      e.dataTransfer.setData('itemId', item.id);
                    }
                  "
                >
                  <div class="flex items-center gap-2">
                    <!-- Barra de Prioridade -->
                    <div
                      class="w-1 h-8 rounded-full flex-shrink-0"
                      :class="{
                        'bg-ruby-500': item.priority === 'high',
                        'bg-yellow-500': item.priority === 'medium',
                        'bg-green-500': item.priority === 'low',
                        'bg-slate-300': item.priority === 'none',
                      }"
                    />

                    <!-- Conteúdo Principal -->
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center justify-between">
                        <div class="flex items-center gap-2 flex-1 min-w-0">
                          <h4
                            class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate"
                          >
                            {{ item.title }}
                          </h4>
                          <span
                            class="flex-shrink-0 px-2 py-0.5 text-xs rounded-full"
                            :style="{
                              backgroundColor: item.stageColor + '20',
                              color: item.stageColor,
                            }"
                          >
                            {{ item.stageName }}
                          </span>
                        </div>
                        <div
                          class="flex items-center gap-2 text-xs text-slate-500"
                        >
                          <span class="text-slate-400">
                            {{ new Date(item.created_at).toLocaleDateString() }}
                          </span>
                          <div class="flex items-center gap-1">
                            <fluent-icon icon="automation" size="12" />
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </transition>
      </div>
    </div>

    <!-- Substituir o Event Details Modal pelo KanbanItemDetails -->
    <Modal
      v-if="selectedItem && showItemDetails"
      v-model:show="showItemDetails"
      :on-close="handleCloseDetails"
      size="full-width"
    >
      <KanbanItemDetails
        v-if="selectedItem"
        :item="selectedItem"
        @close="handleCloseDetails"
        @edit="handleItemEdit"
        @item-updated="fetchKanbanItems"
      />
    </Modal>

    <!-- Add Event Modal -->
    <Modal
      v-model:show="showAddModal"
      size="full-width"
      :on-close="() => (showAddModal = false)"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.ADD_ITEM') }}
        </h3>
        <KanbanItemForm
          v-if="store.getters['funnel/getSelectedFunnel']"
          :funnel-id="store.getters['funnel/getSelectedFunnel'].id"
          :initial-date="selectedDate"
          @saved="handleItemCreated"
          @close="showAddModal = false"
        />
      </div>
    </Modal>

    <!-- Adicione o Modal de Edição -->
    <Modal
      v-model:show="showEditModal"
      size="full-width"
      :on-close="() => (showEditModal = false)"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.EDIT_ITEM') }}
        </h3>
        <KanbanItemForm
          v-if="selectedItemToEdit"
          :funnel-id="store.getters['funnel/getSelectedFunnel'].id"
          :stage="selectedItemToEdit.funnel_stage"
          :initial-data="selectedItemToEdit"
          :is-editing="true"
          @saved="handleItemUpdated"
          @close="showEditModal = false"
        />
      </div>
    </Modal>
  </div>
</template>

<style lang="scss" scoped>
.calendar-container {
  @apply bg-white dark:bg-slate-900 h-full flex flex-col;
  position: relative;
  isolation: isolate;
}

.mini-calendar-section {
  @apply relative flex flex-col;
  z-index: 3;
  background-color: inherit;
  height: 100%;
  -ms-overflow-style: none; /* IE and Edge */
  scrollbar-width: none; /* Firefox */

  > div {
    display: flex;
    flex-direction: column;
    -ms-overflow-style: none;
    scrollbar-width: none;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &::-webkit-scrollbar {
    display: none;
  }
}

.mini-calendar {
  .grid-cols-7 {
    grid-template-columns: repeat(7, minmax(0, 1fr));
  }
  flex-shrink: 0;
}

.calendar-grid {
  @apply grid;
  flex: 1;
  min-height: 0;
  border-left: 1px solid #e2e8f0;
  border-top: 1px solid #e2e8f0;
  position: relative;
  isolation: isolate;
  z-index: 1;
  height: calc(100% - 48px);
  overflow-y: auto;

  &[data-view-mode='week'] {
    grid-template-rows: 1fr;
    display: grid;

    > div:not(.time-column) {
      flex: 1;
      height: 100%;
    }
  }

  &[data-view-mode='month'] {
    grid-template-rows: repeat(6, 1fr);
  }
}

.calendar-header {
  @apply sticky top-0;
  z-index: 2;
  background-color: inherit;
}

.week-day-header {
  position: relative;

  &:not(:last-child)::after {
    content: '';
    @apply absolute right-0 top-1/2 -translate-y-1/2 h-4 w-px bg-slate-200 dark:bg-slate-700;
  }
}

.calendar-day {
  @apply p-2 relative;
  height: 100%;
  border-right: 1px solid #e2e8f0;
  border-bottom: 1px solid #e2e8f0;
  border-top: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
  isolation: isolate;

  .dark & {
    border-right-color: #334155;
    border-bottom-color: #334155;
    border-top-color: #334155;
  }

  &:hover {
    z-index: 1;
  }

  > div {
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  .day-events-container {
    @apply mt-1 relative;
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    min-height: 0;
    -ms-overflow-style: none;
    scrollbar-width: none;

    &::-webkit-scrollbar {
      display: none;
    }
  }

  &[data-view-mode='week'] {
    height: 100%;
    min-height: 100%;
    overflow: hidden;
    border: none; // Remove border from calendar day cells
  }
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--color-border);
  border-top: 3px solid var(--color-woot);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

// Estilizar a scrollbar horizontal
.overflow-x-auto {
  scrollbar-width: thin;
  scrollbar-color: #94a3b8 transparent;

  &::-webkit-scrollbar {
    height: 6px;
  }

  &::-webkit-scrollbar-track {
    background: transparent;
  }

  &::-webkit-scrollbar-thumb {
    background-color: #94a3b8;
    border-radius: 3px;
  }
}

.dark .overflow-x-auto {
  scrollbar-color: #475569 transparent;

  &::-webkit-scrollbar-thumb {
    background-color: #475569;
  }
}

// Adicionar estilos para a transição
.overflow-hidden {
  overflow: hidden;
}

// Ajustar scrollbar para ser mais sutil
.overflow-x-auto {
  &::-webkit-scrollbar {
    height: 4px;
  }

  &::-webkit-scrollbar-thumb {
    @apply bg-slate-300 dark:bg-slate-600;
    border-radius: 2px;
  }

  &:hover {
    &::-webkit-scrollbar-thumb {
      @apply bg-slate-400 dark:bg-slate-500;
    }
  }
}

.recent-items-section {
  @apply relative;
  z-index: 3;
  width: 100%;
  background-color: inherit;
  flex-shrink: 0;
}

.month-summary {
  @apply relative;
  z-index: 3;
  background-color: inherit;
  flex-shrink: 0;
  height: 48px;
}

// Eventos de hoje
.today-events-section {
  @apply relative;
  padding: 0;
}

.events-list {
  flex: 1;
  min-height: 0;
  -ms-overflow-style: none;
  scrollbar-width: none;

  &::-webkit-scrollbar {
    display: none;
  }
}

// Update grid styles to show only time slot lines
.calendar-grid {
  &[data-view-mode='week'] {
    border: none; // Remove outer border
    height: 100%;
    overflow: hidden;

    > div:not(.time-column) {
      border: none; // Remove borders from grid containers
    }
  }
}

// Update time slots background styles
.absolute.inset-0 {
  > div {
    border-color: rgba(226, 232, 240, 0.15); // Make border more subtle
    height: 100% !important; // Forçar altura proporcional
  }
}

.calendar-day {
  &[data-view-mode='week'] {
    height: 100%;
    min-height: 100%;
    border: none;
    position: relative;
    padding: 8px;
  }
}
</style>
