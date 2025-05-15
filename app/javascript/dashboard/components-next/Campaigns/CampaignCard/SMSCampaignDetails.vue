<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { messageStamp } from 'shared/helpers/timeHelper';
import dayjs from 'dayjs';
import 'dayjs/locale/pt-br';
import timezone from 'dayjs/plugin/timezone';
import utc from 'dayjs/plugin/utc';

import { useI18n } from 'vue-i18n';

defineProps({
  inboxName: {
    type: String,
    default: '',
  },
  inboxIcon: {
    type: String,
    default: '',
  },
  scheduledAt: {
    type: Number,
    default: 0,
  },
});
// Configurar dayjs com plugins necessários
dayjs.extend(utc);
dayjs.extend(timezone);
dayjs.locale('pt-br');

const { t } = useI18n();

// Função para verificar se scheduledAt é válido antes de formatá-lo
const formatScheduledDate = timestamp => {
  // Se o timestamp for 0, null, undefined ou uma data inválida, retorna um texto padrão
  if (!timestamp || timestamp === 0) {
    return t(
      'CAMPAIGN.SMS.CARD.CAMPAIGN_DETAILS.NOT_SCHEDULED',
      'Não agendado'
    );
  }

  // Converter para fuso horário brasileiro
  const brasilDate = dayjs(timestamp).tz('America/Sao_Paulo');

  // Formatar no padrão brasileiro
  return brasilDate.format('D [de] MMM, HH:mm');
};
</script>

<template>
  <span class="flex-shrink-0 text-sm text-n-slate-11 whitespace-nowrap">
    {{ t('CAMPAIGN.SMS.CARD.CAMPAIGN_DETAILS.SENT_FROM') }}
  </span>
  <div class="flex items-center gap-1.5 flex-shrink-0">
    <Icon :icon="inboxIcon" class="flex-shrink-0 text-n-slate-12 size-3" />
    <span class="text-sm font-medium text-n-slate-12">
      {{ inboxName }}
    </span>
  </div>

  <span class="flex-shrink-0 text-sm text-n-slate-11 whitespace-nowrap">
    {{ t('CAMPAIGN.SMS.CARD.CAMPAIGN_DETAILS.ON') }}
  </span>
  <span class="flex-1 text-sm font-medium truncate text-n-slate-12">
    {{ formatScheduledDate(scheduledAt) }}
  </span>
</template>
