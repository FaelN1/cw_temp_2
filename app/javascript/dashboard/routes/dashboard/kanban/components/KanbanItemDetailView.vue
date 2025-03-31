<script setup>
import { ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import KanbanAPI from '../../../../api/kanban';
import KanbanItemDetails from './KanbanItemDetails.vue';
import KanbanItemForm from './KanbanItemForm.vue';
import { useStore } from 'vuex';

const props = defineProps({
  itemId: {
    type: [Number, String],
    required: true,
  },
  forceReload: {
    type: Number,
    default: 0,
  },
});

const emit = defineEmits(['back', 'itemUpdated']);
const { t } = useI18n();
const store = useStore();

const item = ref(null);
const isLoading = ref(true);
const isEditing = ref(false);

// Mover fetchItemDetails para antes do watch
const fetchItemDetails = async () => {
  try {
    console.log(
      '[DEBUG KanbanItemDetailView] fetchItemDetails - Iniciando...',
      props.itemId
    );
    isLoading.value = true;
    const { data } = await KanbanAPI.getItem(props.itemId);
    console.log(
      '[DEBUG KanbanItemDetailView] fetchItemDetails - Data recebida:',
      data
    );

    // Atualizar com os novos dados
    item.value = data;
    console.log('[DEBUG KanbanItemDetailView] Item atualizado');
  } catch (error) {
    console.error(
      '[DEBUG KanbanItemDetailView] fetchItemDetails - Erro:',
      error
    );
  } finally {
    isLoading.value = false;
  }
};

// Watch após a definição da função
watch(
  [() => props.itemId, () => props.forceReload],
  () => {
    // Limpar estado atual antes de buscar novo item
    item.value = null;
    isEditing.value = false;
    console.log(
      '[DEBUG KanbanItemDetailView] Estados limpos antes de buscar novo item'
    );

    console.log('[DEBUG KanbanItemDetailView] Fetching new item details...');
    fetchItemDetails();
  },
  { immediate: true }
);

const handleBack = () => {
  console.log('[DEBUG KanbanItemDetailView] handleBack - Iniciando...');
  console.log(
    '[DEBUG KanbanItemDetailView] handleBack - Item atual:',
    item.value
  );
  console.log(
    '[DEBUG KanbanItemDetailView] handleBack - Estado de edição:',
    isEditing.value
  );

  // Limpar estados
  item.value = null;
  isEditing.value = false;

  console.log('[DEBUG KanbanItemDetailView] handleBack - Estados limpos');
  emit('back');
};

const handleEdit = () => {
  isEditing.value = true;
};

const handleClose = () => {
  isEditing.value = false;
};

const handleItemUpdated = () => {
  emit('itemUpdated');
  isEditing.value = false; // Voltar para modo de visualização após edição
};

const handleDetailsDeleted = () => {
  emit('itemUpdated');
  emit('back');
};

const selectedFunnel = store.getters['funnel/getSelectedFunnel'];
</script>

<template>
  <div
    class="flex flex-col h-full w-full bg-white dark:bg-slate-900 overflow-hidden"
  >
    <!-- Header -->
    <div
      class="border-b border-slate-200 dark:border-slate-700 px-4 py-3 flex items-center justify-between"
    >
      <div class="flex items-center gap-2">
        <button
          class="p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800"
          @click="handleBack"
        >
          <fluent-icon icon="arrow-chevron-left" size="20" />
        </button>
        <h2 class="text-lg font-medium">
          {{
            isLoading
              ? t('LOADING')
              : item?.item_details?.title || t('ITEM_DETAILS')
          }}
        </h2>
      </div>

      <div v-if="!isEditing && !isLoading" class="flex items-center gap-2">
        <button
          class="p-2 rounded-md bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300"
          @click="handleEdit"
        >
          <span class="flex items-center gap-1">
            <fluent-icon icon="edit" size="16" />
            {{ t('KANBAN.FORM.EDIT_ITEM') }}
          </span>
        </button>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="flex-1 flex justify-center items-center py-12">
      <span
        class="w-8 h-8 border-2 border-t-woot-500 border-r-woot-500 border-b-transparent border-l-transparent rounded-full animate-spin"
      />
    </div>

    <!-- Content -->
    <div v-else class="flex-1 overflow-auto">
      <!-- Modo de visualização -->
      <KanbanItemDetails
        v-if="!isEditing && item"
        :item="item"
        @close="handleBack"
        @edit="handleEdit"
        @item-updated="handleItemUpdated"
        @deleted="handleDetailsDeleted"
      />

      <!-- Modo de edição -->
      <KanbanItemForm
        v-if="isEditing && item && selectedFunnel"
        :funnel-id="selectedFunnel.id"
        :stage="item.funnel_stage"
        :position="item.position"
        :initial-data="item"
        is-editing
        @saved="handleItemUpdated"
        @close="handleClose"
      />
    </div>
  </div>
</template>

<style lang="scss" scoped>
/* Estilos para animação de carregamento */
@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.animate-spin {
  animation: spin 1s linear infinite;
}
</style>
