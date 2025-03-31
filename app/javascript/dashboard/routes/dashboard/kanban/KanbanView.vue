<script setup>
import { ref, onMounted, watch, computed, provide } from 'vue';
import { useStore } from 'vuex';
import KanbanTab from './components/KanbanTab.vue';
import ListTab from './components/ListTab.vue';
import AgendaTab from './components/AgendaTab.vue';
import FunnelsManager from './components/FunnelsManager.vue';
import MessageTemplates from './components/MessageTemplates.vue';
import KanbanAutomations from './components/KanbanAutomations.vue';
import AutomationEditor from './components/AutomationEditor.vue';
import KanbanItemDetailView from './components/KanbanItemDetailView.vue';

const store = useStore();
const currentView = ref('kanban');
const selectedItemId = ref(null);
const forceReloadCounter = ref(0);

const isLoading = computed(() => store.state.kanban.loading);
const kanbanItems = computed(() => {
  const items = store.getters['kanban/getKanbanItems'];
  console.log(
    '[VIEW-DEBUG] Computed kanbanItems obtendo dados do store:',
    items.length
  );
  console.log(
    '[VIEW-DEBUG] IDs dos itens no KanbanView:',
    items.map(i => i.id)
  );
  return items;
});
const selectedFunnel = computed(
  () => store.getters['funnel/getSelectedFunnel']
);
const labelsMap = ref({});

// Controle centralizado de carregamento
const isInitialLoad = ref(true);

// Disponibilizar dados para componentes filhos
provide('labelsMap', labelsMap);

// Modificar o watch para usar o store
watch(
  selectedFunnel,
  async newFunnel => {
    if (newFunnel?.id) {
      console.log('[VIEW-DEBUG] Funil selecionado mudou para:', newFunnel.id);
      console.log('[VIEW-DEBUG] Chamando fetchKanbanItems do store');
      await store.dispatch('kanban/fetchKanbanItems');
      console.log(
        '[VIEW-DEBUG] fetchKanbanItems concluído, items:',
        kanbanItems.value.length
      );
      isInitialLoad.value = false;
    }
  },
  { immediate: true }
);

// Modificar onMounted para usar o store
onMounted(async () => {
  if (selectedFunnel.value?.id) {
    await store.dispatch('kanban/fetchKanbanItems');
    isInitialLoad.value = false;
  }
});

const switchView = view => {
  currentView.value = view;
  selectedItemId.value = null; // Resetar o item selecionado ao trocar de view
};

// Função para visualizar detalhes do item
const handleItemClick = item => {
  selectedItemId.value = item.id;
  forceReloadCounter.value++;
  currentView.value = 'item-detail';
};

// Voltar para a view anterior
const handleBackFromDetail = () => {
  currentView.value = 'kanban'; // ou guardar a última view ativa
  selectedItemId.value = null;
};

// Simplificar para usar o store para atualizações
const handleItemsUpdated = async () => {
  console.log('[VIEW-DEBUG] handleItemsUpdated chamado');
  await store.dispatch('kanban/fetchKanbanItems');
  console.log(
    '[VIEW-DEBUG] handleItemsUpdated concluído, itens:',
    kanbanItems.value.length
  );
};

const getCurrentComponent = computed(() => {
  switch (currentView.value) {
    case 'kanban':
      return KanbanTab;
    case 'list':
      return ListTab;
    case 'agenda':
      return AgendaTab;
    case 'funnels':
      return FunnelsManager;
    case 'templates':
      return MessageTemplates;
    case 'automations':
      return KanbanAutomations;
    case 'automation-editor':
      return AutomationEditor;
    case 'item-detail':
      return KanbanItemDetailView;
    default:
      return KanbanTab;
  }
});
</script>

<template>
  <div class="flex h-full w-full overflow-hidden">
    <keep-alive>
      <component
        :is="getCurrentComponent"
        :currentView="currentView"
        :kanban-items="kanbanItems"
        :labels-map="labelsMap"
        :is-loading="isLoading"
        :itemId="selectedItemId"
        :force-reload="forceReloadCounter"
        @switchView="switchView"
        @items-updated="handleItemsUpdated"
        @itemClick="handleItemClick"
        @back="handleBackFromDetail"
        @itemUpdated="handleItemsUpdated"
      />
    </keep-alive>
  </div>
</template>

<style scoped>
.flex {
  min-height: 0;
  min-width: 0;
  height: 100%;
  width: 100%;
}
</style>
