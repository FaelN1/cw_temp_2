<script setup>
import { reactive, computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { WHATSAPP_CAMPAIGN_SUPPORTED_INBOX_TYPES } from 'shared/constants/whatsappCampaign';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const store = useStore();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  allInboxes: useMapGetter('inboxes/getInboxes'),
};

const initialState = {
  title: '',
  message: '',
  inboxId: null,
  scheduledAt: null,
  selectedAudience: [],
  file: null,
  selectedTemplate: null,
  templateVariables: {}, // Armazenar valores das variáveis do template
};

const state = reactive({ ...initialState });

// Template options state
const availableTemplates = ref([]);
const loadingTemplates = ref(false);
const templateVariableFields = ref([]); // Armazena os campos de variáveis detectados

// Determina o tipo de canal baseado no inbox selecionado
const selectedInboxType = computed(() => {
  if (!state.inboxId) return null;

  const selectedInbox = formState.allInboxes.value.find(
    inbox => inbox.id === state.inboxId
  );

  return selectedInbox ? selectedInbox.channel_type : null;
});

// Verifica se é um canal API
const isAPIChannel = computed(() => {
  return selectedInboxType.value === 'Channel::Api';
});

// Verifica se é um canal WhatsApp
const isWhatsAppChannel = computed(() => {
  return selectedInboxType.value === 'Channel::Whatsapp';
});

// Carrega os templates quando um canal WhatsApp é selecionado
watch(
  () => state.inboxId,
  async newInboxId => {
    if (newInboxId && isWhatsAppChannel.value) {
      await loadWhatsAppTemplates(newInboxId);
    } else {
      availableTemplates.value = [];
      state.selectedTemplate = null;
      templateVariableFields.value = [];
      state.templateVariables = {};
    }
  }
);

// Função para carregar os templates do WhatsApp
const loadWhatsAppTemplates = async inboxId => {
  try {
    loadingTemplates.value = true;
    // Aqui assumimos que os templates estão disponíveis no store
    // Se não estiverem, você precisará fazer uma requisição à API
    const templates =
      store.getters['inboxes/getWhatsAppTemplates'](inboxId) || [];
    availableTemplates.value = templates.map(template => ({
      value: template.id,
      label: template.name,
      template: template,
    }));
  } catch (error) {
    console.error('Erro ao carregar templates:', error);
    availableTemplates.value = [];
  } finally {
    loadingTemplates.value = false;
  }
};

// Detecta variáveis em um texto de template
const extractTemplateVariables = text => {
  const regex = /{{(\d+)}}/g;
  const variables = [];
  let match;

  while ((match = regex.exec(text)) !== null) {
    variables.push({
      key: match[1], // O número dentro dos colchetes
      fullMatch: match[0], // A expressão completa {{n}}
    });
  }

  return variables;
};

// Função para lidar com a seleção de template
const handleTemplateChange = templateId => {
  const selectedTemplate =
    availableTemplates.value.find(t => t.value === templateId)?.template ||
    null;

  state.selectedTemplate = selectedTemplate;
  state.templateVariables = {}; // Resetar variáveis quando trocar o template

  // Se encontrou o template, extrair variáveis
  if (selectedTemplate) {
    // Procurar componentes do tipo BODY para extrair variáveis
    const bodyComponent = selectedTemplate.components?.find(
      c => c.type === 'BODY'
    );

    if (bodyComponent && bodyComponent.text) {
      const extractedVars = extractTemplateVariables(bodyComponent.text);

      // Criar campos para cada variável encontrada
      templateVariableFields.value = extractedVars.map(v => ({
        id: v.key,
        name: `var_${v.key}`,
        label: `Variável {{${v.key}}}`,
        placeholder: `Valor para {{${v.key}}}`,
        value: '',
      }));
    } else {
      templateVariableFields.value = [];
    }
  } else {
    templateVariableFields.value = [];
  }
};

// Atualizar valor da variável quando alterado
const updateTemplateVariable = (id, value) => {
  state.templateVariables[id] = value;
};

// Atualiza as regras de validação de acordo com o tipo de canal
const rules = computed(() => {
  const baseRules = {
    title: { required, minLength: minLength(1) },
    inboxId: { required },
    scheduledAt: { required },
    selectedAudience: { required },
  };

  // Se for canal WhatsApp, requer um template selecionado
  if (isWhatsAppChannel.value) {
    return {
      ...baseRules,
      selectedTemplate: { required },
    };
  }

  // Se for canal API, requer uma mensagem
  if (isAPIChannel.value) {
    return {
      ...baseRules,
      message: { required, minLength: minLength(1) },
    };
  }

  return baseRules;
});

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  // Added to disable the scheduled at field from being set to the current time
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(
  () =>
    formState.labels.value.map(label => ({
      value: label.id,
      label: `${label.title}`,
    })) || []
);

// Filtra inboxes para mostrar apenas os tipos suportados (API e WhatsApp)
const inboxOptions = computed(() => {
  const supportedInboxes = formState.allInboxes.value.filter(inbox =>
    WHATSAPP_CAMPAIGN_SUPPORTED_INBOX_TYPES.includes(inbox.channel_type)
  );
  return mapToOptions(supportedInboxes, 'id', 'name');
});

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.WHATSAPP.CREATE.FORM';
  return v$.value[field]?.$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  message: getErrorMessage('message', 'MESSAGE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
  template:
    isWhatsAppChannel.value && !state.selectedTemplate
      ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.ERROR')
      : '',
}));

const isSubmitDisabled = computed(() => {
  // Verificar se todos os campos de variáveis foram preenchidos quando aplicável
  if (isWhatsAppChannel.value && templateVariableFields.value.length > 0) {
    const allVariablesFilled = templateVariableFields.value.every(
      field => !!state.templateVariables[field.id]
    );
    return v$.value.$invalid || !allVariablesFilled;
  }
  return v$.value.$invalid;
});

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, { ...initialState });
  templateVariableFields.value = [];
};

const handleCancel = () => emit('cancel');

// Adicionamos a função para tratar o upload do arquivo
const handleFileChange = event => {
  const file = event.target.files[0] || null;
  state.file = file;
};

const prepareCampaignDetails = () => {
  const commonDetails = {
    title: state.title,
    inbox_id: state.inboxId,
    scheduled_at: formatToUTCString(state.scheduledAt),
    audience: state.selectedAudience?.map(id => ({
      id,
      type: 'Label',
    })),
  };

  if (isWhatsAppChannel.value && state.selectedTemplate) {
    // Preparar os parâmetros do template incluindo as variáveis preenchidas
    const processedParams = {};

    // Transformar variáveis para o formato esperado pela API
    Object.keys(state.templateVariables).forEach(key => {
      processedParams[key] = state.templateVariables[key];
    });

    return {
      ...commonDetails,
      template_params: {
        name: state.selectedTemplate.name,
        namespace: state.selectedTemplate.namespace || '',
        language: state.selectedTemplate.language || 'pt_BR',
        processed_params: processedParams,
      },
      message: '', // Campo obrigatório, mesmo que vazio para templates
    };
  }
  return {
    ...commonDetails,
    message: state.message,
    file: state.file,
  };
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};

// Translation keys
const titleLabel = t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL');
const titlePlaceholder = t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER');
const messageLabel = t('CAMPAIGN.WHATSAPP.CREATE.FORM.MESSAGE.LABEL');
const messagePlaceholder = t(
  'CAMPAIGN.WHATSAPP.CREATE.FORM.MESSAGE.PLACEHOLDER'
);
const inboxLabel = t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL');
const inboxPlaceholder = t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER');
const audienceLabel = t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL');
const audiencePlaceholder = t(
  'CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.PLACEHOLDER'
);
const scheduledAtLabel = t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL');
const scheduledAtPlaceholder = t(
  'CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER'
);
const templateLabel = t(
  'CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.LABEL',
  'Selecionar Template'
);
const templatePlaceholder = t(
  'CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.PLACEHOLDER',
  'Escolha um template'
);
const fileLabel = t(
  'CAMPAIGN.WHATSAPP.CREATE.FORM.FILE.LABEL',
  'Adicionar arquivo único'
);
const variablesTitle = t(
  'CAMPAIGN.WHATSAPP.CREATE.FORM.VARIABLES.TITLE',
  'Variáveis do Template'
);
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="titleLabel"
      :placeholder="titlePlaceholder"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ inboxLabel }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="inboxPlaceholder"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <!-- Campos específicos para Canal API -->
    <template v-if="isAPIChannel">
      <TextArea
        v-model="state.message"
        :label="messageLabel"
        :placeholder="messagePlaceholder"
        show-character-count
        :message="formErrors.message"
        :message-type="formErrors.message ? 'error' : 'info'"
      />

      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ fileLabel }}
        </label>
        <input type="file" accept="*/*" @change="handleFileChange" />
      </div>
    </template>

    <!-- Campos específicos para Canal WhatsApp -->
    <div v-if="isWhatsAppChannel" class="flex flex-col gap-1">
      <label for="template" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ templateLabel }}
      </label>
      <ComboBox
        id="template"
        v-model="state.selectedTemplate"
        :options="availableTemplates"
        :has-error="!!formErrors.template"
        :placeholder="templatePlaceholder"
        :message="formErrors.template"
        :loading="loadingTemplates"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
        @update:model-value="handleTemplateChange"
      />

      <!-- Exibe detalhes do template selecionado -->
      <div
        v-if="state.selectedTemplate"
        class="mt-2 p-3 bg-slate-50 dark:bg-slate-800 rounded-md"
      >
        <h4 class="font-medium text-sm">{{ state.selectedTemplate.name }}</h4>
        <div v-if="state.selectedTemplate.components" class="mt-1 text-sm">
          <div
            v-for="(component, index) in state.selectedTemplate.components"
            :key="index"
          >
            <div
              v-if="component.type === 'BODY'"
              class="text-slate-700 dark:text-slate-300"
            >
              {{ component.text }}
            </div>
          </div>
        </div>
      </div>

      <!-- Campos de variáveis do template -->
      <div
        v-if="templateVariableFields.length > 0"
        class="mt-4 p-3 bg-slate-50 dark:bg-slate-800 rounded-md"
      >
        <h4 class="font-medium text-sm mb-2">{{ variablesTitle }}</h4>
        <div
          v-for="field in templateVariableFields"
          :key="field.id"
          class="mb-3"
        >
          <label
            :for="field.name"
            class="mb-0.5 text-sm font-medium text-n-slate-12"
          >
            {{ field.label }}
          </label>
          <Input
            :id="field.name"
            v-model="state.templateVariables[field.id]"
            :placeholder="field.placeholder"
            required
          />
        </div>
      </div>
    </div>

    <div class="flex flex-col gap-1">
      <label for="audience" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ audienceLabel }}
      </label>
      <TagMultiSelectComboBox
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="audienceLabel"
        :placeholder="audiencePlaceholder"
        :has-error="!!formErrors.audience"
        :message="formErrors.audience"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <Input
      v-model="state.scheduledAt"
      :label="scheduledAtLabel"
      type="datetime-local"
      :placeholder="scheduledAtPlaceholder"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <div class="flex items-center justify-between w-full gap-3">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 n-blue-text hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
