<script setup>
import { ref, computed, onMounted, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import KanbanAPI from '../../../../api/kanban';
import WootMessageEditor from '../../../../components/widgets/WootWriter/Editor.vue';
import WootInput from '../../../../../v3/components/Form/Input.vue';
import WootToggle from './Toggle.vue';
import WootSelect from '../../../../../v3/components/Form/Select.vue';
import WootButton from '../../../../components/ui/WootButton.vue';
import { default as FluentIcon } from 'shared/components/FluentIcon/Icon.vue';
import dashboardIcons from 'shared/components/FluentIcon/dashboard-icons.json';
import FunnelAPI from '../../../../api/funnel';

const props = defineProps({
  initialData: {
    type: Object,
    default: () => ({}),
  },
  isEditing: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const emit = defineEmits(['saved', 'close']);
const isLoading = ref(false);
const error = ref(null);
const errors = ref({});
const kanbanItems = ref([]);

// Estado para controlar quando os dados estão prontos
const isDataReady = ref(false);

// Buscar todos os funis ao montar o componente
onMounted(async () => {
  try {
    isLoading.value = true;
    // Dispara a action para buscar todos os funis
    await store.dispatch('funnel/fetch');
  } catch (error) {
    console.error('Erro ao carregar funis:', error);
  } finally {
    isLoading.value = false;
  }
});

// Computed para obter todos os funis
const funnels = computed(() => store.getters['funnel/getFunnels']);

// Computed para obter o funil selecionado
const selectedFunnel = computed(
  () => store.getters['funnel/getSelectedFunnel']
);

// Função para garantir que o valor é uma string
const ensureString = value => (value ? String(value) : '');

// Computed para obter as etapas do funil selecionado
const funnelStages = computed(() => {
  // Busca o funil diretamente dos records usando o ID atual
  const currentFunnel = funnels.value.find(
    f => String(f.id) === formData.value.funnel_id
  );

  console.log('Calculando funnelStages:', {
    currentFunnel,
    formDataFunnelId: formData.value.funnel_id,
    stages: currentFunnel?.stages,
    currentStageId: formData.value.stage_id,
    availableStageIds: currentFunnel?.stages
      ? Object.keys(currentFunnel.stages)
      : [],
  });

  if (!currentFunnel?.stages) return [];

  const stages = Object.entries(currentFunnel.stages)
    .map(([id, stage]) => ({
      value: String(id),
      label: stage.name,
      position: stage.position,
    }))
    .sort((a, b) => a.position - b.position);

  console.log('Stages calculadas:', stages);
  return stages;
});

// Computed para transformar os funis em options para o select
const funnelOptions = computed(() => {
  return funnels.value.map(funnel => ({
    value: String(funnel.id),
    label: funnel.name,
  }));
});

// Form data atualizado para incluir o funil_id
const formData = ref({
  funnel_id: ensureString(props.initialData.funnel_id),
  stage_id: ensureString(props.initialData.stage_id),
  title: props.initialData.title || '',
  content: props.initialData.content || '',
  webhook: {
    enabled: props.initialData.webhook?.enabled || false,
    url: props.initialData.webhook?.url || '',
    method: props.initialData.webhook?.method || 'POST',
  },
  conditions: {
    enabled: props.initialData.conditions?.enabled || false,
    rules: props.initialData.conditions?.rules || [],
  },
});

// Validation
const validateForm = () => {
  errors.value = {};

  if (!selectedFunnel.value?.id) {
    errors.value.funnel = t(
      'KANBAN.MESSAGE_TEMPLATES.FORM.ERRORS.FUNNEL_REQUIRED'
    );
  }

  if (!formData.value.stage_id) {
    errors.value.stage = t(
      'KANBAN.MESSAGE_TEMPLATES.FORM.ERRORS.STAGE_REQUIRED'
    );
  }

  if (!formData.value.title.trim()) {
    errors.value.title = t(
      'KANBAN.MESSAGE_TEMPLATES.FORM.ERRORS.TITLE_REQUIRED'
    );
  }

  if (!formData.value.content.trim()) {
    errors.value.content = t(
      'KANBAN.MESSAGE_TEMPLATES.FORM.ERRORS.CONTENT_REQUIRED'
    );
  }

  if (formData.value.webhook.enabled && !formData.value.webhook.url.trim()) {
    errors.value.webhookUrl = t(
      'KANBAN.MESSAGE_TEMPLATES.FORM.ERRORS.WEBHOOK_URL_REQUIRED'
    );
  }

  return Object.keys(errors.value).length === 0;
};

// Atualiza o handler de submit para incluir o funil e etapa
const handleSubmit = async () => {
  try {
    if (!validateForm()) return;

    isLoading.value = true;
    const currentFunnel = funnels.value.find(
      f => String(f.id) === formData.value.funnel_id
    );

    if (!currentFunnel) {
      throw new Error('Funil não encontrado');
    }

    // Cria uma cópia do funil mantendo a estrutura original
    const updatedFunnel = {
      ...currentFunnel,
      stages: { ...currentFunnel.stages }, // Clona stages para preservar IDs
    };

    const selectedStageId = formData.value.stage_id;
    const currentStage = updatedFunnel.stages[selectedStageId];

    // Preserva a estrutura existente da etapa
    updatedFunnel.stages[selectedStageId] = {
      ...currentStage,
      message_templates: [...(currentStage?.message_templates || [])],
    };

    if (props.isEditing) {
      const templateIndex = updatedFunnel.stages[
        selectedStageId
      ].message_templates.findIndex(t => t.id === props.initialData.id);

      if (templateIndex > -1) {
        updatedFunnel.stages[selectedStageId].message_templates[templateIndex] =
          {
            ...props.initialData,
            ...formData.value,
            updated_at: new Date().toISOString(),
          };
      }
    } else {
      updatedFunnel.stages[selectedStageId].message_templates.push({
        id: Date.now(),
        ...formData.value,
        created_at: new Date().toISOString(),
      });
    }

    await FunnelAPI.update(currentFunnel.id, updatedFunnel);
    await store.dispatch('funnel/fetch');
    emit('saved', formData.value);
  } catch (error) {
    errors.value = {
      submit: t('KANBAN.MESSAGE_TEMPLATES.FORM.ERRORS.SAVE_ERROR'),
    };
  } finally {
    isLoading.value = false;
  }
};

// Busca os itens do Kanban para extrair os campos disponíveis
const fetchKanbanItems = async () => {
  try {
    isLoading.value = true;
    const currentFunnel = store.getters['funnel/getSelectedFunnel'];

    if (!currentFunnel?.id) {
      console.error('Nenhum funil selecionado');
      return;
    }

    const response = await KanbanAPI.getItems(currentFunnel.id);

    kanbanItems.value = response.data.map(item => ({
      id: item.id,
      title: item.item_details.title || '',
      description: item.item_details.description || '',
      priority: item.item_details.priority || 'none',
      assignee: item.item_details.assignee || null,
      position: item.position,
      funnel_stage: item.funnel_stage,
      item_details: item.item_details,
      custom_attributes: item.custom_attributes || {},
      createdAt: new Date(item.created_at).toLocaleDateString(),
    }));
  } catch (error) {
    console.error('Erro ao carregar itens do Kanban:', error);
  } finally {
    isLoading.value = false;
  }
};

// Computed para extrair campos únicos dos itens
const availableFields = computed(() => {
  return [
    { value: 'item_details.title', label: 'Título' },
    { value: 'item_details.description', label: 'Descrição' },
    { value: 'item_details.priority', label: 'Prioridade' },
    { value: 'item_details.agent_id', label: 'Agente' },
    { value: 'item_details.conversation_id', label: 'Conversa' },
    { value: 'item_details.value', label: 'Valor' },
    { value: 'funnel_stage', label: 'Etapa do Funil' },
  ].sort((a, b) => a.label.localeCompare(b.label));
});

// Computed para o v-model do funnel_id
const selectedFunnelId = computed({
  get: () => {
    console.log('selectedFunnelId.get chamado:', formData.value.funnel_id);
    return formData.value.funnel_id;
  },
  set: async value => {
    console.log('selectedFunnelId.set chamado com:', value);
    formData.value.funnel_id = ensureString(value);
    await handleFunnelChange(value);
  },
});

// Computed para o v-model do stage_id
const selectedStageId = computed({
  get: () => {
    console.log('selectedStageId.get chamado:', formData.value.stage_id);
    return formData.value.stage_id;
  },
  set: value => {
    console.log('selectedStageId.set chamado com:', value);
    formData.value.stage_id = ensureString(value);
  },
});

// Available HTTP methods for webhook
const httpMethods = [
  { value: 'GET', label: 'GET' },
  { value: 'POST', label: 'POST' },
  { value: 'PUT', label: 'PUT' },
  { value: 'PATCH', label: 'PATCH' },
  { value: 'DELETE', label: 'DELETE' },
];

// Computed para controlar a exibição do editor de regras condicionais
const showConditionsEditor = computed(() => formData.value.conditions.enabled);

const addConditionRule = () => {
  formData.value.conditions.rules.push({
    field: '',
    operator: 'equals',
    value: '',
  });
};

const removeConditionRule = index => {
  formData.value.conditions.rules.splice(index, 1);
};

// Handler para quando um funil é selecionado
const handleFunnelChange = async value => {
  try {
    console.log('handleFunnelChange chamado com valor:', value);
    // Atualiza o ID do funil no formData
    formData.value.funnel_id = ensureString(value);
    console.log('FormData após atualizar funnel_id:', formData.value);

    // Busca o funil completo dos records do store
    const selectedFunnel = funnels.value.find(
      f => String(f.id) === formData.value.funnel_id
    );
    console.log('Funil encontrado no handleFunnelChange:', selectedFunnel);

    if (selectedFunnel) {
      // Atualiza o funil selecionado no store
      await store.dispatch('funnel/setSelectedFunnel', selectedFunnel);
      console.log('Funil atualizado no store');

      await nextTick();

      // Só limpa a etapa se não estiver editando ou se mudar o funil
      if (
        !props.isEditing ||
        formData.value.funnel_id !== ensureString(props.initialData.funnel_id)
      ) {
        const stages = Object.keys(selectedFunnel.stages || {});
        console.log('Limpando stage_id');
        formData.value.stage_id = stages[0] || '';
      } else {
        console.log('Mantendo stage_id:', formData.value.stage_id);
      }
    }
  } catch (error) {
    console.error('Erro ao mudar funil:', error);
  }
};

// Carrega os itens quando o componente é montado
onMounted(async () => {
  try {
    isLoading.value = true;

    console.log('Dados iniciais:', {
      initialData: props.initialData,
      isEditing: props.isEditing,
      initialStageId: props.initialData.stage_id,
    });

    // Busca todos os funis
    await store.dispatch('funnel/fetch');
    console.log('Funis carregados:', funnels.value);

    // Aguarda o DOM atualizar
    await nextTick();

    console.log('FormData antes da inicialização:', formData.value);
    // Inicializa o formData com os valores convertidos para string
    formData.value = {
      ...formData.value,
      funnel_id: ensureString(props.initialData.funnel_id),
      stage_id: ensureString(props.initialData.stage_id),
    };
    console.log('FormData após inicialização:', formData.value);

    // Se houver um funil_id inicial, seleciona ele
    if (props.initialData.funnel_id) {
      console.log('Tentando selecionar funil:', props.initialData.funnel_id);
      const funnel = funnels.value.find(
        f => String(f.id) === ensureString(props.initialData.funnel_id)
      );
      console.log('Funil encontrado:', funnel);

      if (funnel) {
        // Atualiza o funil selecionado no store
        await store.dispatch('funnel/setSelectedFunnel', funnel);
        console.log('Funil selecionado no store');

        // Verifica se a stage_id existe nas stages do funil
        const stages = Object.keys(funnel.stages || {});
        console.log('Stages disponíveis:', stages);

        const initialStageId = ensureString(props.initialData.stage_id);
        console.log('Stage ID inicial:', initialStageId);

        const stageExists = stages.some(id => String(id) === initialStageId);
        console.log('Stage existe?', stageExists);

        // Aguarda o DOM atualizar
        await nextTick();

        console.log('Estado dos selects antes da atualização:', {
          funnel_id: formData.value.funnel_id,
          stage_id: formData.value.stage_id,
          funnelOptions: funnelOptions.value,
          stageOptions: funnelStages.value,
        });

        // Força a atualização dos selects
        if (!stageExists) {
          formData.value.stage_id = stages[0] || '';
        }

        console.log('Estado dos selects após atualização:', {
          funnel_id: formData.value.funnel_id,
          stage_id: formData.value.stage_id,
          funnelOptions: funnelOptions.value,
          stageOptions: funnelStages.value,
        });

        console.log('FormData atualizado:', formData.value);
      }
    }

    await fetchKanbanItems();
    await nextTick();
    console.log('Estado final antes de isDataReady:', {
      formData: formData.value,
      funnelOptions: funnelOptions.value,
      stageOptions: funnelStages.value,
    });
    isDataReady.value = true;
  } catch (error) {
    console.error('Erro ao inicializar formulário:', error);
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <form class="message-template-form" @submit.prevent="handleSubmit">
    <h3 class="text-lg font-medium mb-4">
      {{
        t(
          isEditing
            ? 'KANBAN.MESSAGE_TEMPLATES.EDIT.TITLE'
            : 'KANBAN.MESSAGE_TEMPLATES.NEW'
        )
      }}
    </h3>
    <div class="form-grid">
      <!-- Coluna Esquerda -->
      <div class="left-column">
        <!-- Seleção de Etapa do Funil -->
        <div class="form-section">
          <h3 class="section-title">
            {{ t('KANBAN.MESSAGE_TEMPLATES.FORM.FUNNEL_INFO') }}
          </h3>

          <!-- Loading state para os funis -->
          <div v-if="isLoading" class="loading-state mb-4">
            {{ t('KANBAN.LOADING_FUNNELS') }}
          </div>

          <!-- Seletores -->
          <div v-if="isDataReady" class="mb-2">
            <WootSelect
              v-model="selectedFunnelId"
              name="funnel_id"
              :label="t('KANBAN.MESSAGE_TEMPLATES.FORM.FUNNEL.LABEL')"
              :placeholder="
                t('KANBAN.MESSAGE_TEMPLATES.FORM.FUNNEL.PLACEHOLDER')
              "
              :options="funnelOptions"
              :error="errors.funnel"
              :value="formData.funnel_id"
            />

            <WootSelect
              v-model="selectedStageId"
              name="stage_id"
              :label="t('KANBAN.MESSAGE_TEMPLATES.FORM.STAGE.LABEL')"
              :placeholder="
                t('KANBAN.MESSAGE_TEMPLATES.FORM.STAGE.PLACEHOLDER')
              "
              :options="funnelStages"
              :error="errors.stage"
              class="mb-2"
              :value="formData.stage_id"
            />
          </div>
        </div>

        <!-- Informações Básicas (apenas título) -->
        <div class="form-section">
          <h3 class="section-title">
            {{ t('KANBAN.MESSAGE_TEMPLATES.FORM.BASIC_INFO') }}
          </h3>

          <WootInput
            v-model="formData.title"
            name="title"
            :label="t('KANBAN.MESSAGE_TEMPLATES.FORM.TITLE.LABEL')"
            :placeholder="t('KANBAN.MESSAGE_TEMPLATES.FORM.TITLE.PLACEHOLDER')"
            :error="errors.title"
            class="mb-4"
          />
        </div>

        <!-- Configuração de Webhook -->
        <div class="form-section">
          <div class="flex items-center justify-between mb-4">
            <h3 class="section-title mb-0">
              {{ t('KANBAN.MESSAGE_TEMPLATES.FORM.WEBHOOK.TITLE') }}
            </h3>
            <WootToggle v-model="formData.webhook.enabled" />
          </div>

          <div v-if="formData.webhook.enabled" class="webhook-config">
            <WootInput
              v-model="formData.webhook.url"
              name="webhook_url"
              :label="t('KANBAN.MESSAGE_TEMPLATES.FORM.WEBHOOK.URL.LABEL')"
              :placeholder="
                t('KANBAN.MESSAGE_TEMPLATES.FORM.WEBHOOK.URL.PLACEHOLDER')
              "
              :error="errors.webhookUrl"
            />

            <WootSelect
              v-model="formData.webhook.method"
              name="webhook_method"
              :label="t('KANBAN.MESSAGE_TEMPLATES.FORM.WEBHOOK.METHOD.LABEL')"
              :options="httpMethods"
            />
          </div>
        </div>

        <!-- Condições -->
        <div class="form-section">
          <div class="flex items-center justify-between mb-4">
            <h3 class="section-title mb-0">
              {{ t('KANBAN.MESSAGE_TEMPLATES.FORM.CONDITIONS.TITLE') }}
            </h3>
            <WootToggle v-model="formData.conditions.enabled" />
          </div>

          <div v-if="showConditionsEditor" class="conditions-config space-y-4">
            <div
              v-for="(rule, index) in formData.conditions.rules"
              :key="index"
              class="condition-rule flex items-start gap-2"
            >
              <div class="flex-1">
                <div class="space-y-2">
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-slate-300"
                  >
                    {{
                      t('KANBAN.MESSAGE_TEMPLATES.FORM.CONDITIONS.FIELD.LABEL')
                    }}
                  </label>
                  <select
                    v-model="rule.field"
                    class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-1 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-700 dark:border-slate-600"
                  >
                    <option value="" disabled>
                      {{
                        t(
                          'KANBAN.MESSAGE_TEMPLATES.FORM.CONDITIONS.FIELD.PLACEHOLDER'
                        )
                      }}
                    </option>
                    <option
                      v-for="field in availableFields"
                      :key="field.value"
                      :value="field.value"
                    >
                      {{ field.label }}
                    </option>
                  </select>
                </div>
              </div>
              <div class="w-32">
                <div class="space-y-2">
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-slate-300"
                  >
                    {{
                      t(
                        'KANBAN.MESSAGE_TEMPLATES.FORM.CONDITIONS.OPERATOR.LABEL'
                      )
                    }}
                  </label>
                  <select
                    v-model="rule.operator"
                    class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-1 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-700 dark:border-slate-600"
                  >
                    <option value="equals">Igual a</option>
                    <option value="contains">Contém</option>
                    <option value="starts_with">Começa com</option>
                    <option value="ends_with">Termina com</option>
                  </select>
                </div>
              </div>
              <div class="flex-1">
                <div class="space-y-2">
                  <label
                    class="block text-sm font-medium text-slate-700 dark:text-slate-300"
                  >
                    {{
                      t('KANBAN.MESSAGE_TEMPLATES.FORM.CONDITIONS.VALUE.LABEL')
                    }}
                  </label>
                  <input
                    v-model="rule.value"
                    type="text"
                    class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:ring-1 focus:ring-woot-500 focus:border-woot-500 dark:bg-slate-700 dark:border-slate-600"
                    :placeholder="
                      t(
                        'KANBAN.MESSAGE_TEMPLATES.FORM.CONDITIONS.VALUE.PLACEHOLDER'
                      )
                    "
                  />
                </div>
              </div>
              <WootButton
                variant="clear"
                color-scheme="secondary"
                size="small"
                @click="removeConditionRule(index)"
              >
                <fluent-icon icon="delete" size="16" :icons="dashboardIcons" />
              </WootButton>
            </div>

            <WootButton
              variant="clear"
              size="small"
              class="w-full"
              @click="addConditionRule"
            >
              <fluent-icon
                icon="add"
                size="16"
                class="mr-2"
                :icons="dashboardIcons"
              />
              {{ t('KANBAN.MESSAGE_TEMPLATES.FORM.CONDITIONS.ADD_RULE') }}
            </WootButton>
          </div>
        </div>
      </div>

      <!-- Coluna Direita (Editor) -->
      <div class="right-column">
        <div class="editor-section">
          <WootMessageEditor
            v-model="formData.content"
            :placeholder="
              t('KANBAN.MESSAGE_TEMPLATES.FORM.CONTENT.PLACEHOLDER')
            "
            :error="errors.content"
            class="content-editor"
          />
        </div>
      </div>
    </div>

    <!-- Botões de Ação -->
    <div class="form-actions">
      <WootButton
        variant="clear"
        color-scheme="secondary"
        @click="emit('close')"
      >
        {{ t('KANBAN.ACTIONS.CANCEL') }}
      </WootButton>
      <WootButton variant="primary" type="submit">
        {{ t('KANBAN.ACTIONS.SAVE') }}
      </WootButton>
    </div>
  </form>
</template>

<style lang="scss" scoped>
.message-template-form {
  @apply space-y-4;
}

.form-grid {
  @apply grid grid-cols-2 gap-4;
}

.left-column {
  @apply space-y-4;
}

.right-column {
  @apply sticky top-0;
  @apply border border-dashed border-woot-500 rounded-lg;
}

.form-section {
  @apply px-4 py-2 bg-slate-50 dark:bg-slate-800 rounded-lg;
}

.editor-section {
  @apply h-full bg-slate-50 dark:bg-slate-800 rounded-lg p-4;
  min-height: calc(100vh - 400px);
}

.section-title {
  @apply text-base font-medium text-slate-700 dark:text-slate-300 mb-2;
}

.webhook-config,
.conditions-config {
  @apply mt-4;
}

.form-actions {
  @apply flex justify-end gap-2 pt-4;
}

.condition-rule {
  @apply p-3 bg-white dark:bg-slate-700 rounded-lg;
}

.content-editor {
  @apply h-full;
  :deep(.woot-editor) {
    @apply border border-dashed border-woot-500 rounded-lg;
    @apply p-2 bg-white dark:bg-slate-700;
    height: calc(100vh - 450px);
  }
}

.error-message {
  @apply text-sm text-ruby-500;
}

.loading-state {
  @apply text-sm text-slate-600 dark:text-slate-400;
}
</style>
