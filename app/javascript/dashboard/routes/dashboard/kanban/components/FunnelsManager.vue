<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import FunnelsHeader from './FunnelsHeader.vue';
import Modal from '../../../../components/Modal.vue';
import FunnelAPI from '../../../../api/funnel';
import FunnelForm from './FunnelForm.vue';
import { emitter } from 'shared/helpers/mitt';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const { t } = useI18n();
const store = useStore();
const loading = ref(false);
const funnels = ref([]);

// Estado para os modais
const showDeleteModal = ref(false);
const showEditModal = ref(false);
const funnelToDelete = ref(null);
const funnelToEdit = ref(null);

const fetchFunnels = async () => {
  loading.value = true;
  try {
    const { data } = await FunnelAPI.get();
    funnels.value = data.map(funnel => {
      // Garantir que os estágios tenham sempre posição definida
      const stages = Object.entries(funnel.stages || {}).reduce(
        (acc, [id, stage]) => ({
          ...acc,
          [id]: {
            ...stage,
            id,
            position: parseInt(stage.position, 10) || 0,
            message_templates: stage.message_templates || [],
          },
        }),
        {}
      );

      console.log('Estágios carregados para funil:', funnel.name, stages);

      return {
        ...funnel,
        stages,
      };
    });

    console.log('Funis carregados:', funnels.value);
  } catch (error) {
    console.error('Erro ao carregar funis:', error);
  } finally {
    loading.value = false;
  }
};

const confirmDelete = funnel => {
  funnelToDelete.value = funnel;
  showDeleteModal.value = true;
};

const handleDelete = async () => {
  try {
    loading.value = true;
    await FunnelAPI.delete(funnelToDelete.value.id);
    await fetchFunnels();

    emitter.emit('newToastMessage', {
      message: 'Funil excluído com sucesso',
      action: { type: 'success' },
    });

    showDeleteModal.value = false;
    funnelToDelete.value = null;
  } catch (error) {
    emitter.emit('newToastMessage', {
      message: t('KANBAN.ERRORS.DELETE_FUNNEL_WITH_ITEMS'),
      action: { type: 'error' },
    });
  } finally {
    loading.value = false;
  }
};

const startEdit = funnel => {
  funnelToEdit.value = {
    ...funnel,
    id: String(funnel.id),
    stages: Object.entries(funnel.stages || {}).reduce(
      (acc, [key, stage]) => ({
        ...acc,
        [String(key)]: {
          ...stage,
          id: String(stage.id || key),
        },
      }),
      {}
    ),
    settings: funnel.settings || {}, // Preserva todas as configurações
    agents: funnel.settings?.agents || [], // Carrega os agentes do settings
  };

  console.log('Dados para edição:', funnelToEdit.value); // Para debug
  showEditModal.value = true;
};

const handleEdit = async updatedFunnel => {
  try {
    loading.value = true;

    console.log('Dados recebidos do formulário:', updatedFunnel);

    // Prepara o payload mantendo a estrutura existente
    const payload = {
      ...updatedFunnel,
      settings: {
        ...(funnelToEdit.value.settings || {}),
        agents: updatedFunnel.agents || [], // Usa os agentes do formulário
        last_optimized_at: funnelToEdit.value.settings?.last_optimized_at,
        optimization_history:
          funnelToEdit.value.settings?.optimization_history || [],
      },
    };

    // Remove os agentes do nível principal para evitar duplicação
    delete payload.agents;

    console.log('Payload final:', payload);

    await FunnelAPI.update(funnelToEdit.value.id, payload);
    await store.dispatch('funnel/fetch');
    await fetchFunnels();

    emitter.emit('newToastMessage', {
      message: 'Funil atualizado com sucesso',
      action: { type: 'success' },
    });

    showEditModal.value = false;
  } catch (error) {
    console.error('Erro ao atualizar funil:', error);
    emitter.emit('newToastMessage', {
      message: 'Erro ao atualizar o funil',
      action: { type: 'error' },
    });
  } finally {
    loading.value = false;
  }
};

const duplicateFunnel = async funnel => {
  try {
    loading.value = true;
    const timestamp = Date.now();

    // Gera novos IDs para as etapas
    const newStages = Object.entries(funnel.stages).reduce(
      (acc, [_, stage]) => {
        const newId = `stage_${timestamp}_${stage.position}`;
        return {
          ...acc,
          [newId]: {
            ...stage,
            id: newId,
            message_templates: stage.message_templates?.map(template => ({
              ...template,
              id: `template_${timestamp}_${template.id}`,
              stage_id: newId,
            })),
          },
        };
      },
      {}
    );

    const newFunnel = {
      name: `${funnel.name} (cópia)`,
      description: funnel.description,
      active: funnel.active,
      stages: newStages,
      settings: {
        ...funnel.settings,
        agents: funnel.settings?.agents || [],
      },
    };

    await FunnelAPI.create(newFunnel);
    await fetchFunnels();
  } catch (error) {
    console.error('Erro ao duplicar funil:', error);
  } finally {
    loading.value = false;
  }
};

// Função para ordenar as etapas de um funil por posição
const getSortedStages = stages => {
  if (!stages) return [];

  console.log('Ordenando estágios:', stages);

  // Converter objeto de etapas em array
  const stagesArray = Object.entries(stages)
    .map(([id, stage]) => ({
      id,
      ...stage,
      position: parseInt(stage.position, 10) || 0,
    }))
    .sort((a, b) => a.position - b.position);

  console.log(
    'Estágios ordenados:',
    stagesArray.map(s => `${s.name} (${s.position})`)
  );
  return stagesArray;
};

const emit = defineEmits(['switch-view']);

onMounted(() => {
  fetchFunnels();
});
</script>

<template>
  <div class="flex flex-col h-full bg-white dark:bg-slate-900">
    <FunnelsHeader
      @switch-view="view => emit('switch-view', view)"
      @funnel-created="fetchFunnels"
    />

    <div class="funnels-content p-6 flex-1 overflow-y-auto">
      <!-- Loading State -->
      <div v-if="loading" class="flex justify-center items-center py-12">
        <span class="loading-spinner" />
      </div>

      <!-- Empty State -->
      <div
        v-else-if="!funnels.length"
        class="flex flex-col items-center justify-center py-12 text-slate-600"
      >
        <fluent-icon icon="task" size="48" class="mb-4" />
        <p class="text-lg">Nenhum funil encontrado</p>
        <p class="text-sm">
          Crie um novo funil para começar a organizar seus itens
        </p>
      </div>

      <!-- Funnels List -->
      <div v-else class="grid gap-4">
        <div
          v-for="funnel in funnels"
          :key="funnel.id"
          class="funnel-card p-4 border rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 relative"
        >
          <!-- Botões de Ação -->
          <div class="absolute top-4 right-4 flex items-center gap-1">
            <woot-button
              variant="clear"
              size="small"
              class="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100"
              @click="startEdit(funnel)"
            >
              <fluent-icon icon="edit" size="16" />
            </woot-button>
            <woot-button
              variant="clear"
              size="small"
              class="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100"
              @click="duplicateFunnel(funnel)"
            >
              <fluent-icon icon="copy" size="16" />
            </woot-button>
            <woot-button
              variant="clear"
              size="small"
              class="text-slate-600 dark:text-slate-400 hover:text-ruby-600 dark:hover:text-ruby-400"
              @click="confirmDelete(funnel)"
            >
              <fluent-icon icon="delete" size="16" />
            </woot-button>
          </div>

          <div class="flex flex-col gap-4">
            <!-- Informações básicas -->
            <div class="flex items-center gap-2">
              <h3 class="text-lg font-medium">{{ funnel.name }}</h3>
              <span
                :class="[
                  'text-xs px-2 py-0.5 rounded-full',
                  funnel.active
                    ? 'bg-green-100 text-green-700'
                    : 'bg-red-100 text-red-700',
                ]"
              >
                {{ funnel.active ? 'Ativo' : 'Inativo' }}
              </span>
            </div>

            <!-- Data de criação -->
            <p class="text-xs text-slate-500">
              Criado em: {{ new Date(funnel.created_at).toLocaleDateString() }}
            </p>

            <!-- Etapas -->
            <div class="flex flex-wrap gap-2">
              <span
                v-for="stage in getSortedStages(funnel.stages)"
                :key="stage.id"
                class="px-2 py-1 text-xs font-medium rounded-full flex items-center gap-1 group relative"
                :style="{
                  backgroundColor: `${stage.color}20`,
                  color: stage.color,
                }"
              >
                {{ stage.name }}
                <!-- Badge de templates se houver -->
                <span
                  v-if="stage.message_templates?.length"
                  class="ml-1 px-1.5 text-[10px] rounded-full bg-white/50"
                >
                  {{ stage.message_templates.length }}
                </span>

                <!-- Tooltip com templates -->
                <div
                  v-if="stage.message_templates?.length"
                  class="absolute hidden group-hover:block bg-white dark:bg-slate-800 shadow-lg rounded-lg p-3 z-10 min-w-[250px] top-full left-0 mt-1"
                >
                  <div class="flex items-center gap-2 mb-2">
                    <fluent-icon icon="chat" size="16" class="text-woot-500" />
                    <p class="text-xs font-medium">Templates de Mensagem</p>
                  </div>
                  <div class="space-y-2">
                    <div
                      v-for="template in stage.message_templates"
                      :key="template.id"
                      class="p-2 bg-slate-50 dark:bg-slate-700 rounded"
                    >
                      <div class="flex items-center justify-between mb-1">
                        <p class="text-xs font-medium">{{ template.title }}</p>
                        <span
                          v-if="template.webhook?.enabled"
                          class="text-[10px] px-1.5 py-0.5 rounded bg-blue-100 dark:bg-blue-900 text-blue-700 dark:text-blue-300"
                        >
                          Webhook
                        </span>
                      </div>
                      <p
                        class="text-[11px] text-slate-600 dark:text-slate-400 line-clamp-2"
                      >
                        {{ template.content }}
                      </p>
                    </div>
                  </div>
                </div>
              </span>
            </div>

            <!-- Agentes -->
            <div
              v-if="funnel.settings?.agents?.length"
              class="flex flex-wrap gap-2"
            >
              <div
                v-for="agent in funnel.settings.agents"
                :key="agent.id"
                class="flex items-center gap-2 px-2 py-1 bg-slate-100 dark:bg-slate-800 rounded-lg"
              >
                <Avatar :name="agent.name" :src="agent.thumbnail" :size="20" />
                <span class="text-xs text-slate-700 dark:text-slate-300">
                  {{ agent.name }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de Edição -->
    <Modal
      v-model:show="showEditModal"
      :on-close="() => (showEditModal = false)"
      class="funnel-modal"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.FUNNELS.EDIT.TITLE') }}
        </h3>
        <FunnelForm
          v-if="funnelToEdit"
          :is-editing="true"
          :initial-data="funnelToEdit"
          @saved="handleEdit"
          @close="showEditModal = false"
        />
      </div>
    </Modal>

    <!-- Modal de Confirmação de Exclusão -->
    <Modal
      v-model:show="showDeleteModal"
      :on-close="() => (showDeleteModal = false)"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.FUNNELS.DELETE.TITLE') }}
        </h3>
        <p class="text-sm text-slate-600 mb-6">
          {{
            t('KANBAN.FUNNELS.DELETE.DESCRIPTION', {
              name: funnelToDelete?.name,
            })
          }}
        </p>
        <div class="flex justify-end gap-2">
          <woot-button
            variant="clear"
            size="small"
            @click="showDeleteModal = false"
          >
            {{ t('KANBAN.CANCEL') }}
          </woot-button>
          <woot-button
            variant="danger"
            size="small"
            :loading="loading"
            @click="handleDelete"
          >
            {{ t('KANBAN.DELETE') }}
          </woot-button>
        </div>
      </div>
    </Modal>
  </div>
</template>

<style lang="scss" scoped>
.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--color-border-light);
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

.funnels-content {
  min-height: 0; // Importante para o scroll funcionar
}

:deep(.funnel-modal) {
  .modal-container {
    @apply max-w-[1024px] w-[90vw];
  }
}
</style>
