<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import KanbanAPI from '../../../../api/kanban';
import agents from '../../../../api/agents';

const props = defineProps({
  currentStage: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'items-created']);
const { t } = useI18n();
const store = useStore();

const loading = ref(false);
const selectedFunnel = computed(
  () => store.getters['funnel/getSelectedFunnel']
);
const itemsList = ref([]);
const agentsList = ref([]);
const loadingAgents = ref(false);

// Form para novo item
const newItem = ref({
  title: '',
  priority: 'none',
  agent_id: '',
});

// Prioridades disponíveis
const priorityOptions = [
  { id: 'none', name: t('KANBAN.PRIORITY_LABELS.NONE') },
  { id: 'low', name: t('KANBAN.PRIORITY_LABELS.LOW') },
  { id: 'medium', name: t('KANBAN.PRIORITY_LABELS.MEDIUM') },
  { id: 'high', name: t('KANBAN.PRIORITY_LABELS.HIGH') },
  { id: 'urgent', name: t('KANBAN.PRIORITY_LABELS.URGENT') },
];

const stages = computed(() => {
  if (!selectedFunnel.value?.stages) return [];

  return Object.entries(selectedFunnel.value.stages)
    .map(([id, stage]) => ({
      id,
      name: stage.name,
      position: stage.position,
    }))
    .sort((a, b) => a.position - b.position);
});

const selectedStage = ref(props.currentStage || '');

// Função para carregar os agentes
const fetchAgents = async () => {
  try {
    loadingAgents.value = true;
    const { data } = await agents.get();
    agentsList.value = data;
  } catch (error) {
    console.error('Erro ao carregar agentes:', error);
  } finally {
    loadingAgents.value = false;
  }
};

const addItemToList = () => {
  if (!newItem.value.title.trim()) return;

  itemsList.value.push({
    ...newItem.value,
    id: Date.now(), // ID temporário para a lista
  });

  // Limpa o form
  newItem.value = {
    title: '',
    priority: 'none',
    agent_id: '',
  };
};

const removeItemFromList = itemId => {
  itemsList.value = itemsList.value.filter(item => item.id !== itemId);
};

const handleSubmit = async () => {
  if (!itemsList.value.length || !selectedStage.value) return;

  try {
    loading.value = true;
    const items = itemsList.value.map((item, index) => ({
      funnel_id: Number(selectedFunnel.value.id),
      funnel_stage: selectedStage.value,
      position: index + 1,
      item_details: {
        title: item.title,
        priority: item.priority,
        agent_id: item.agent_id || null,
      },
    }));

    console.log('[BULK-DEBUG] Items a serem criados:', items);
    console.log('[BULK-DEBUG] Verificando store antes da criação:');
    console.log(
      '[BULK-DEBUG] Itens no store:',
      store.state.kanban.items.map(i => ({ id: i.id, stage: i.funnel_stage }))
    );

    const createdItems = await Promise.all(
      items.map(item => KanbanAPI.createItem(item))
    );

    console.log(
      '[BULK-DEBUG] Items criados com sucesso:',
      createdItems.map(r => r.data)
    );

    // Verifica se os itens foram adicionados ao store
    try {
      console.log(
        '[BULK-DEBUG] Tentando atualizar store via kanban/itemUpdated'
      );
      await store.dispatch('kanban/itemUpdated');

      console.log('[BULK-DEBUG] Store após itemUpdated:');
      console.log(
        '[BULK-DEBUG] Itens no store após:',
        store.state.kanban.items.map(i => ({ id: i.id, stage: i.funnel_stage }))
      );

      // Verificar se todos os itens criados estão no store
      const allItemsInStore = createdItems.every(response =>
        store.state.kanban.items.some(item => item.id === response.data.id)
      );

      console.log(
        '[BULK-DEBUG] Todos os itens criados estão no store?',
        allItemsInStore
      );

      if (!allItemsInStore) {
        console.log(
          '[BULK-DEBUG] itemUpdated não adicionou todos os itens, tentando fetchKanbanItems'
        );
        await store.dispatch('kanban/fetchKanbanItems');

        // Verificar novamente
        const allItemsNowInStore = createdItems.every(response =>
          store.state.kanban.items.some(item => item.id === response.data.id)
        );

        console.log(
          '[BULK-DEBUG] Todos os itens estão no store após fetchKanbanItems?',
          allItemsNowInStore
        );
      }
    } catch (e) {
      console.error('[BULK-DEBUG] Erro ao atualizar store:', e);
      // Tenta usar fetchKanbanItems como fallback
      console.log('[BULK-DEBUG] Tentando fetchKanbanItems como alternativa');
      await store.dispatch('kanban/fetchKanbanItems');
    }

    emit(
      'items-created',
      createdItems.map(response => response.data)
    );
    emit('close');
  } catch (error) {
    console.error('[BULK-DEBUG] Erro ao criar itens:', error);
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  fetchAgents();
});
</script>

<template>
  <div class="bulk-add-modal">
    <div class="p-6">
      <h3 class="text-lg font-medium mb-4">
        {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.ACTIONS.ADD_ITEM') }}
      </h3>

      <div class="stage-selector mb-4">
        <label class="block text-sm font-medium mb-2">
          {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.STAGE.LABEL') }}
        </label>
        <select
          v-model="selectedStage"
          class="w-full p-2 border rounded-lg bg-white dark:bg-slate-800"
        >
          <option value="" disabled>
            {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.STAGE.PLACEHOLDER') }}
          </option>
          <option v-for="stage in stages" :key="stage.id" :value="stage.id">
            {{ stage.name }}
          </option>
        </select>
      </div>

      <!-- Formulário de novo item -->
      <div class="new-item-form grid grid-cols-3 gap-4 mb-4">
        <div class="col-span-3">
          <label class="block text-sm font-medium mb-2">
            {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.INPUTS.TITLE.LABEL') }}
          </label>
          <input
            v-model="newItem.title"
            type="text"
            class="w-full p-2 border rounded-lg bg-white dark:bg-slate-800"
            :placeholder="
              t('KANBAN.BULK_ACTIONS.BULK_FORM.INPUTS.TITLE.PLACEHOLDER')
            "
          />
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">
            {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.INPUTS.PRIORITY.LABEL') }}
          </label>
          <select
            v-model="newItem.priority"
            class="w-full p-2 border rounded-lg bg-white dark:bg-slate-800"
          >
            <option
              v-for="option in priorityOptions"
              :key="option.id"
              :value="option.id"
            >
              {{ option.name }}
            </option>
          </select>
        </div>

        <div class="col-span-2">
          <label class="block text-sm font-medium mb-2">
            {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.INPUTS.AGENT.LABEL') }}
          </label>
          <select
            v-model="newItem.agent_id"
            class="w-full p-2 border rounded-lg bg-white dark:bg-slate-800"
            :disabled="loadingAgents"
          >
            <option value="">
              {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.INPUTS.AGENT.PLACEHOLDER') }}
            </option>
            <option
              v-for="agent in agentsList"
              :key="agent.id"
              :value="agent.id"
            >
              {{ agent.name }}
            </option>
          </select>
        </div>

        <div class="col-span-3">
          <woot-button
            variant="primary"
            size="small"
            :disabled="!newItem.title.trim()"
            @click="addItemToList"
          >
            {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.ACTIONS.ADD_TO_LIST') }}
          </woot-button>
        </div>
      </div>

      <!-- Lista de itens -->
      <div
        v-if="itemsList.length"
        class="items-list mb-4 border rounded-lg overflow-hidden"
      >
        <div
          v-for="item in itemsList"
          :key="item.id"
          class="item-row flex items-center justify-between p-3 border-b last:border-b-0 hover:bg-slate-50 dark:hover:bg-slate-800"
        >
          <div class="flex items-center gap-4">
            <span class="font-medium">{{ item.title }}</span>
            <span
              class="px-2 py-1 text-xs font-medium rounded-full"
              :class="`bg-${item.priority}-50 dark:bg-${item.priority}-800 text-${item.priority}-800 dark:text-${item.priority}-50`"
            >
              {{ t(`KANBAN.PRIORITY_LABELS.${item.priority.toUpperCase()}`) }}
            </span>
            <span v-if="item.agent_id" class="text-sm text-slate-600">
              {{ agentsList.find(a => a.id === item.agent_id)?.name }}
            </span>
          </div>
          <woot-button
            variant="clear"
            size="small"
            @click="removeItemFromList(item.id)"
          >
            <fluent-icon icon="delete" size="16" />
          </woot-button>
        </div>
      </div>

      <div class="flex justify-end gap-2">
        <woot-button variant="clear" size="small" @click="$emit('close')">
          {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.ACTIONS.CANCEL') }}
        </woot-button>
        <woot-button
          variant="primary"
          size="small"
          :loading="loading"
          :disabled="!itemsList.length || !selectedStage"
          @click="handleSubmit"
        >
          {{ t('KANBAN.BULK_ACTIONS.BULK_FORM.ACTIONS.CONFIRM') }}
        </woot-button>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.bulk-add-modal {
  width: 100%;
  max-width: 800px;
}

.items-list {
  max-height: 300px;
  overflow-y: auto;
}
</style>
