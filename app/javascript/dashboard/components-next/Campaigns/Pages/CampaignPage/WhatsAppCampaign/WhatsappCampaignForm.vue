<script setup>
import { reactive, computed } from 'vue';
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
  file: null, // novo campo para armazenar o arquivo
};

const state = reactive({ ...initialState });

const rules = {
  title: { required, minLength: minLength(1) },
  message: { required, minLength: minLength(1) },
  inboxId: { required },
  scheduledAt: { required },
  selectedAudience: { required },
};

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

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
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
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  message: getErrorMessage('message', 'MESSAGE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
}));

const isSubmitDisabled = computed(() => v$.value.$invalid);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, { ...initialState });
};

const handleCancel = () => emit('cancel');

// Adicionamos a função para tratar o upload do arquivo
const handleFileChange = event => {
  const file = event.target.files[0] || null;
  state.file = file;
};

const prepareCampaignDetails = () => ({
  title: state.title,
  message: state.message,
  inbox_id: state.inboxId,
  scheduled_at: formatToUTCString(state.scheduledAt),
  audience: state.selectedAudience?.map(id => ({
    id,
    type: 'Label',
  })),
  file: state.file, // inclusão do arquivo no payload
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};

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
        Adicionar arquivo único
      </label>
      <input type="file" accept="*/*" @change="handleFileChange" />
    </div>

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
      :min="currentDateTime"
      :placeholder="scheduledAtPlaceholder"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <!-- Novo campo para upload de arquivo -->

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
