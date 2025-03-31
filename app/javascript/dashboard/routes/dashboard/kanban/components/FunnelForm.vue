<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import FunnelAPI from '../../../../api/funnel';
import StageColorPicker from './StageColorPicker.vue';
import draggable from 'vuedraggable';
import agents from '../../../../api/agents';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  isEditing: {
    type: Boolean,
    default: false,
  },
  initialData: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['saved', 'close']);
const { t } = useI18n();
const loading = ref(false);

const formData = ref({
  name: props.initialData.name || '',
  description: props.initialData.description || '',
  stages: {},
  agents: props.initialData.agents || [],
});

const stages = ref([]);
const newStage = ref({
  name: '',
  color: '#FF6B6B',
  description: '',
});

const editingStage = ref(null);

const dragOptions = {
  animation: 150,
  ghostClass: 'ghost-card',
};

const vFocus = {
  mounted: el => el.focus(),
};

const agentsList = ref([]);
const loadingAgents = ref(false);
const existingStageIds = ref(new Set());

// Gera o ID baseado no nome
const generateId = name => {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
};

// Gera um ID único apenas se necessário
const generateUniqueId = (baseName, existingStages, currentId = null) => {
  // Se já tem um ID e está editando, mantém o mesmo
  if (currentId && editingStage.value) {
    return currentId;
  }

  const baseId = generateId(baseName);
  const stageIds = existingStages.map(stage => stage.id);

  // Se o ID base não existe, usa ele
  if (!stageIds.includes(baseId)) {
    return baseId;
  }

  // Se existe, adiciona um timestamp para garantir unicidade
  return `${baseId}_${Date.now()}`;
};

// Atualiza o ID apenas para novas etapas
watch(
  () => newStage.value.name,
  newName => {
    if (newName && !editingStage.value) {
      newStage.value.id = generateId(newName);
    }
  }
);

// Converte as etapas para o formato esperado pela API
const formatStagesForAPI = () => {
  const formattedStages = {};

  // Garantir que as posições reflitam a ordem atual
  stages.value.forEach((stage, index) => {
    // Definir explicitamente a posição baseada no índice atual
    const position = index + 1;

    // Pega os templates existentes da etapa atual
    const existingTemplates =
      props.initialData?.stages?.[stage.id]?.message_templates || [];

    formattedStages[stage.id] = {
      name: stage.name,
      color: stage.color,
      position: position, // Garantir que a posição reflita a ordem atual
      description: stage.description,
      message_templates: existingTemplates, // Mantém os templates existentes
    };

    // Debug da posição definida
    console.log(`Formatando para API: ${stage.name} -> posição ${position}`);
  });

  return formattedStages;
};

// Função para lidar com a reordenação das etapas
const handleOrderChange = async () => {
  if (!props.isEditing) return;

  try {
    // Atualizar as posições com base na nova ordem
    stages.value.forEach((stage, index) => {
      stage.position = index + 1;
      console.log(
        `Atualizando posição: ${stage.name} -> posição ${stage.position}`
      );
    });

    const payload = {
      name: formData.value.name,
      description: formData.value.description,
      stages: formatStagesForAPI(),
    };

    console.log('Payload de ordenação:', payload);

    // Atualiza o estado local sem fazer chamada à API
    props.initialData.stages = payload.stages;
  } catch (error) {
    console.error('Erro ao atualizar ordem:', error);
  }
};

const handleAddStage = e => {
  if (e?.target?.closest('.colorpicker--chrome')) {
    return;
  }

  if (!newStage.value.name) return;

  if (editingStage.value) {
    const index = stages.value.findIndex(s => s.id === editingStage.value.id);
    if (index !== -1) {
      stages.value[index] = {
        ...editingStage.value,
        name: newStage.value.name,
        color: newStage.value.color,
        description: newStage.value.description,
        id: editingStage.value.id,
      };

      if (props.isEditing) {
        handleOrderChange();
      }
    }
    editingStage.value = null;
  } else {
    let stageId = generateId(newStage.value.name);
    let counter = 1;

    // Se o ID já existe em outro funil, gera um novo
    while (existingStageIds.value.has(stageId)) {
      stageId = `${generateId(newStage.value.name)}_${counter}`;
      counter++;
    }

    stages.value.push({
      ...newStage.value,
      id: stageId,
    });
    existingStageIds.value.add(stageId);
  }

  newStage.value = {
    name: '',
    color: '#FF6B6B',
    description: '',
  };
};

const removeStage = index => {
  stages.value.splice(index, 1);
};

// Busca todos os funis e coleta os IDs existentes
const fetchExistingStageIds = async () => {
  try {
    const { data: allFunnels } = await FunnelAPI.get();
    existingStageIds.value.clear();

    allFunnels.forEach(funnel => {
      if (funnel.id !== props.initialData?.id) {
        // Ignora o funil atual se estiver editando
        Object.keys(funnel.stages || {}).forEach(id => {
          existingStageIds.value.add(id);
        });
      }
    });
  } catch (error) {
    console.error('Erro ao carregar IDs existentes:', error);
  }
};

// Inicializa as etapas se estiver editando
onMounted(() => {
  console.log('FunnelForm mounted, initialData:', props.initialData);

  if (props.isEditing || props.initialData) {
    console.log('Inicializando form com dados:', props.initialData);

    formData.value = {
      name: props.initialData.name || '',
      description: props.initialData.description || '',
      stages: props.initialData.stages || {},
      agents: props.initialData.agents || [],
    };

    console.log('formData atualizado:', formData.value);

    // Inicializa as etapas do template
    if (props.initialData.stages) {
      console.log('Inicializando etapas:', props.initialData.stages);

      stages.value = Object.entries(props.initialData.stages)
        .map(([id, stage]) => {
          const mappedStage = {
            id,
            name: stage.name,
            color: stage.color,
            description: stage.description,
            position: parseInt(stage.position, 10) || 0,
          };
          console.log('Etapa mapeada:', mappedStage);
          return mappedStage;
        })
        .sort((a, b) => a.position - b.position);

      console.log(
        'Etapas inicializadas e ordenadas por posição:',
        stages.value
      );
    }
  }

  fetchAgents();
});

const fetchAgents = async () => {
  try {
    loadingAgents.value = true;
    const { data } = await agents.get();
    // Se tiver agentes pré-selecionados e eles não estiverem na lista, adiciona-os
    if (props.initialData?.agents?.length) {
      props.initialData.agents.forEach(agent => {
        if (!data.find(a => a.id === agent.id)) {
          data.push(agent);
        }
      });
    }
    agentsList.value = data;
  } catch (error) {
    console.error('Erro ao carregar agentes:', error);
  } finally {
    loadingAgents.value = false;
  }
};

const handleSubmit = async () => {
  try {
    loading.value = true;

    // Preparar as etapas mantendo os templates existentes e atualizando posições
    const formattedStages = formatStagesForAPI();

    console.log('Estágios formatados para submit:', formattedStages);

    const payload = {
      name: formData.value.name,
      description: formData.value.description,
      stages: formattedStages,
      agents: formData.value.agents,
    };

    let response;
    if (props.isEditing) {
      // Se estiver editando, mantém os dados existentes
      response = {
        data: {
          ...props.initialData,
          ...payload,
          stages: {
            ...payload.stages,
            // Para cada etapa, mantém os templates se existirem
            ...Object.fromEntries(
              Object.entries(props.initialData.stages || {}).map(
                ([id, stage]) => [
                  id,
                  payload.stages[id]
                    ? {
                        ...payload.stages[id],
                        message_templates: stage.message_templates || [],
                      }
                    : stage,
                ]
              )
            ),
          },
        },
      };
    } else {
      response = await FunnelAPI.create(payload);
    }

    if (response.data) {
      emit('saved', response.data);
    }
  } catch (error) {
    console.error('Erro ao salvar funil:', error);
  } finally {
    loading.value = false;
  }
};

const startEditing = stage => {
  // Preenche o formulário de nova etapa com os dados da etapa selecionada
  newStage.value = {
    id: stage.id,
    name: stage.name,
    color: stage.color,
    description: stage.description,
  };
  editingStage.value = stage;
};

const saveStageEdit = index => {
  if (!editingStage.value) return;

  stages.value[index] = {
    ...stages.value[index],
    name: editingStage.value.name,
    description: editingStage.value.description,
    color: editingStage.value.color,
  };

  editingStage.value = null;

  // Se estiver editando, atualiza imediatamente
  if (props.isEditing) {
    handleOrderChange();
  }
};

const cancelEditing = () => {
  editingStage.value = null;
  // Limpa o formulário de nova etapa
  newStage.value = {
    name: '',
    color: '#FF6B6B',
    description: '',
  };
};

// Adicione um watch para debug
watch(
  () => formData.value.agents,
  newAgents => {
    console.log('Agentes atualizados:', newAgents);
  }
);

const toggleAgent = agent => {
  const index = formData.value.agents.findIndex(a => a.id === agent.id);
  if (index === -1) {
    formData.value.agents.push(agent);
  } else {
    formData.value.agents.splice(index, 1);
  }
};

// Adicionar watch para monitorar mudanças
watch(
  () => stages.value,
  newStages => {
    console.log('Etapas atualizadas:', newStages);
  },
  { deep: true }
);

watch(
  () => formData.value,
  newFormData => {
    console.log('FormData atualizado:', newFormData);
  },
  { deep: true }
);
</script>

<template>
  <form class="funnel-form" @submit.prevent="handleSubmit">
    <div class="grid grid-cols-[1fr_400px] gap-6">
      <!-- Coluna Esquerda - Formulário -->
      <div class="space-y-6">
        <!-- Nome do Funil -->
        <div>
          <label class="block text-sm font-medium mb-2">
            {{ t('KANBAN.FUNNELS.FORM.NAME.LABEL') }}
          </label>
          <input
            v-model="formData.name"
            type="text"
            class="w-full px-3 py-2 border rounded-lg"
            :placeholder="t('KANBAN.FUNNELS.FORM.NAME.PLACEHOLDER')"
            required
          />
        </div>

        <!-- Descrição -->
        <div>
          <label class="block text-sm font-medium mb-2">
            {{ t('KANBAN.FUNNELS.FORM.DESCRIPTION.LABEL') }}
          </label>
          <textarea
            v-model="formData.description"
            rows="3"
            class="w-full px-3 py-2 border rounded-lg"
            :placeholder="t('KANBAN.FUNNELS.FORM.DESCRIPTION.PLACEHOLDER')"
          />
        </div>

        <!-- Formulário Nova Etapa -->
        <div
          class="border rounded-lg p-4 space-y-4"
          :class="{
            'border-2': editingStage,
            'border-slate-200': !editingStage,
          }"
          :style="editingStage ? { borderColor: newStage.color } : {}"
        >
          <h4 class="text-lg font-medium mb-4">
            <div class="flex items-center justify-between">
              <span>{{ t('KANBAN.FUNNELS.FORM.STAGES.TITLE') }}</span>
              <span
                v-if="editingStage"
                class="text-sm px-2 py-1 rounded"
                :style="{
                  backgroundColor: `${newStage.color}20`,
                  color: newStage.color,
                }"
              >
                {{ t('KANBAN.FUNNELS.FORM.STAGES.EDITING') }}
              </span>
            </div>
          </h4>

          <!-- Nome da Etapa -->
          <div>
            <label class="block text-sm font-medium mb-2">
              {{ t('KANBAN.FUNNELS.FORM.STAGES.NAME') }}
            </label>
            <input
              v-model="newStage.name"
              type="text"
              class="w-full px-3 py-2 border rounded-lg"
              :placeholder="t('KANBAN.FUNNELS.FORM.STAGES.NAME_PLACEHOLDER')"
            />
          </div>

          <!-- Cor e Descrição em flex -->
          <div class="flex items-start gap-2">
            <div class="w-[180px] shrink-0">
              <label class="block text-sm font-medium mb-2">
                {{ t('KANBAN.FUNNELS.FORM.STAGES.COLOR') }}
              </label>
              <StageColorPicker v-model="newStage.color" />
            </div>

            <div class="flex-1 min-w-0">
              <label class="block text-sm font-medium mb-2">
                {{ t('KANBAN.FUNNELS.FORM.STAGES.DESCRIPTION') }}
              </label>
              <input
                v-model="newStage.description"
                type="text"
                class="w-full px-3 py-2 border rounded-lg"
                :placeholder="
                  t('KANBAN.FUNNELS.FORM.STAGES.DESCRIPTION_PLACEHOLDER')
                "
              />
            </div>
          </div>

          <div class="flex justify-end">
            <woot-button
              variant="clear"
              size="small"
              :disabled="!newStage.name"
              @click.stop="handleAddStage"
            >
              <fluent-icon
                :icon="editingStage ? 'checkmark' : 'add'"
                size="16"
                class="mr-2"
              />
              {{ t(editingStage ? 'SAVE' : 'KANBAN.FUNNELS.FORM.STAGES.ADD') }}
            </woot-button>
          </div>
        </div>

        <!-- Agentes do Funil -->
        <div class="border rounded-lg p-4 space-y-4">
          <h4 class="text-lg font-medium mb-4">Agentes do Funil</h4>

          <div class="space-y-4">
            <!-- Lista de Todos os Agentes -->
            <div class="grid grid-cols-2 gap-3">
              <div
                v-for="agent in agentsList"
                :key="agent.id"
                class="flex items-center gap-3 p-3 border rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors"
                :class="{
                  'border-woot-500 bg-woot-50 dark:bg-woot-900/20':
                    formData.agents.some(a => a.id === agent.id),
                  'border-slate-200 dark:border-slate-700':
                    !formData.agents.some(a => a.id === agent.id),
                }"
                @click="toggleAgent(agent)"
              >
                <div class="relative">
                  <Avatar
                    :name="agent.name"
                    :src="agent.avatar_url"
                    :size="32"
                    :status="agent.availability_status"
                  />
                  <div
                    v-if="formData.agents.some(a => a.id === agent.id)"
                    class="absolute -top-1 -right-1 w-4 h-4 bg-woot-500 rounded-full flex items-center justify-center"
                  >
                    <fluent-icon
                      icon="checkmark"
                      size="12"
                      class="text-white"
                    />
                  </div>
                </div>

                <div class="flex-1 min-w-0">
                  <div class="font-medium text-sm truncate">
                    {{ agent.name }}
                  </div>
                  <div
                    class="text-xs text-slate-500 dark:text-slate-400 truncate"
                  >
                    {{ agent.email }}
                  </div>
                </div>
              </div>
            </div>

            <!-- Loading State -->
            <div
              v-if="loadingAgents"
              class="flex items-center justify-center py-8"
            >
              <span class="loading-spinner" />
            </div>

            <!-- Empty State -->
            <div
              v-else-if="!agentsList.length"
              class="flex flex-col items-center justify-center py-8 text-slate-400"
            >
              <fluent-icon icon="people" size="32" class="mb-2" />
              <p class="text-sm">Nenhum agente disponível</p>
            </div>

            <!-- Contador de Selecionados -->
            <div
              v-if="formData.agents.length"
              class="flex items-center justify-between px-4 py-2 bg-slate-50 dark:bg-slate-800 rounded-lg"
            >
              <span class="text-sm text-slate-600 dark:text-slate-300">
                {{ formData.agents.length }} agente{{
                  formData.agents.length !== 1 ? 's' : ''
                }}
                selecionado{{ formData.agents.length !== 1 ? 's' : '' }}
              </span>
              <button
                type="button"
                class="text-xs text-ruby-500 hover:text-ruby-600 dark:text-ruby-400 dark:hover:text-ruby-300"
                @click="formData.agents = []"
              >
                Limpar seleção
              </button>
            </div>
          </div>
        </div>

        <!-- Botões -->
        <div class="flex justify-end gap-2">
          <woot-button variant="clear" size="small" @click="emit('close')">
            {{ t('KANBAN.CANCEL') }}
          </woot-button>
          <woot-button
            variant="primary"
            size="small"
            type="submit"
            :loading="loading"
            :disabled="!formData.name || !stages.length"
          >
            {{ t(isEditing ? 'KANBAN.SAVE' : 'KANBAN.CREATE') }}
          </woot-button>
        </div>
      </div>

      <!-- Coluna Direita - Lista de Etapas -->
      <div class="border-woot border border-dashed rounded-lg p-6">
        <div class="sticky top-0">
          <h4 class="text-lg font-medium mb-4">
            {{ t('KANBAN.FUNNELS.FORM.STAGES.PREVIEW') }}
          </h4>

          <!-- Lista de Etapas -->
          <div class="space-y-3">
            <draggable
              v-model="stages"
              :options="dragOptions"
              item-key="id"
              class="space-y-3"
              @change="handleOrderChange"
            >
              <template #item="{ element: stage, index }">
                <div
                  class="flex items-center gap-4 p-3 border rounded-lg cursor-move hover:bg-slate-50"
                >
                  <div
                    class="w-4 h-4 rounded-full"
                    :style="{ backgroundColor: stage.color }"
                  />
                  <div class="flex-1">
                    <div class="flex items-center gap-2">
                      <div class="font-medium">
                        {{ stage.name }}
                      </div>
                      <button
                        type="button"
                        class="text-xs hover:underline"
                        :style="{ color: `${stage.color}99` }"
                        @click.stop="startEditing(stage)"
                      >
                        {{ t('KANBAN.FUNNELS.FORM.STAGES.EDIT_STAGE') }}
                      </button>
                    </div>
                    <div class="text-sm text-slate-600">
                      {{ stage.description }}
                      <span class="text-slate-400">({{ stage.id }})</span>
                    </div>
                  </div>
                  <woot-button
                    variant="clear"
                    size="small"
                    @click="removeStage(index)"
                  >
                    <fluent-icon icon="delete" size="16" />
                  </woot-button>
                </div>
              </template>
            </draggable>

            <!-- Empty State -->
            <div
              v-if="!stages.length"
              class="flex flex-col items-center justify-center py-8 text-slate-400"
            >
              <fluent-icon icon="list" size="32" class="mb-2" />
              <p class="text-sm">
                {{ t('KANBAN.FUNNELS.FORM.STAGES.EMPTY') }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </form>
</template>

<style lang="scss" scoped>
.border-woot {
  border-color: var(--color-woot);
  border-width: 1px;
}

.ghost-card {
  opacity: 0.5;
  background: #c8ebfb;
}

.cursor-move {
  cursor: move;
}

.loading-spinner {
  @apply w-6 h-6 border-2 border-slate-200 border-t-woot-500 rounded-full animate-spin;
}

.agent-card {
  @apply transition-all duration-200;

  &:hover {
    @apply transform scale-[1.02];
  }
}
</style>
