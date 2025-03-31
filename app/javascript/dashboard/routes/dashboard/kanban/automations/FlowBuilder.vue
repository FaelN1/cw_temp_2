<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import AutomationHeader from './components/AutomationHeader.vue';
import FlowCanvas from './components/FlowCanvas.vue';
import FlowToolbar from './components/FlowToolbar.vue';
import { initializeFlow, exportFlow } from './utils/flowHelpers';

const props = defineProps({
  automationId: {
    type: [String, Number],
    default: null,
  },
});

const emit = defineEmits(['close', 'save']);
const store = useStore();

// Estado local
const isLoading = ref(false);
const isSaving = ref(false);
const automationName = ref('Nova Automação');
const automationDescription = ref('');
const isActive = ref(true);

// Verificações de inicialização
onMounted(async () => {
  try {
    isLoading.value = true;

    if (props.automationId) {
      // Carregamento de automação existente...
      await store.dispatch(
        'automationFlow/fetchAutomation',
        props.automationId
      );
      const automation = store.getters['automationFlow/getAutomationById'](
        props.automationId
      );

      if (automation) {
        automationName.value = automation.name;
        automationDescription.value = automation.description || '';
        isActive.value = !!automation.active;

        // Inicializar o flow com os dados existentes
        initializeFlow(store, automation.flow || {});
      }
    } else {
      // Inicializar uma nova automação
      console.log('Inicializando nova automação');
      initializeFlow(store); // Função que configura um novo fluxo com nó de gatilho padrão
    }
  } catch (error) {
    console.error('Erro ao inicializar FlowBuilder:', error);
  } finally {
    isLoading.value = false;
  }
});

// Salvar automação
const saveAutomation = async () => {
  isSaving.value = true;
  try {
    const flowData = exportFlow(store);

    const automationData = {
      id: props.automationId,
      name: automationName.value,
      description: automationDescription.value,
      active: isActive.value,
      flow: flowData,
    };

    await store.dispatch('automationFlow/saveAutomation', automationData);
    emit('save');
  } catch (error) {
    console.error('Erro ao salvar automação:', error);
  } finally {
    isSaving.value = false;
  }
};

// Cancelar edição
const cancelEditing = () => {
  emit('close');
};
</script>

<template>
  <div class="flow-builder-container">
    <AutomationHeader
      v-model:name="automationName"
      v-model:active="isActive"
      :is-saving="isSaving"
      @save="saveAutomation"
      @cancel="cancelEditing"
    />

    <div class="flow-builder-body">
      <FlowCanvas :is-loading="isLoading" />
      <FlowToolbar />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.flow-builder-container {
  @apply flex flex-col h-full bg-white dark:bg-slate-800;

  .flow-builder-body {
    @apply flex flex-row flex-grow overflow-hidden;
  }
}
</style>
