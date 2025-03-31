<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from '../../../../components/Modal.vue';
import FunnelForm from './FunnelForm.vue';
import { default as FluentIcon } from 'shared/components/FluentIcon/Icon.vue';
import dashboardIcons from 'shared/components/FluentIcon/dashboard-icons.json';

const { t } = useI18n();
const emit = defineEmits(['switch-view', 'funnel-created']);

const showNewFunnelModal = ref(false);
const showTemplatesModal = ref(false);
const selectedTemplate = ref(null);

// Adicione um template vazio padrão
const emptyTemplate = {
  name: '',
  description: '',
  stages: {},
  settings: {
    agents: [],
  },
};

// Templates de funis pré-definidos
const funnelTemplates = [
  {
    id: 'sales',
    name: 'Funil de Vendas',
    icon: 'briefcase',
    description: 'Processo de vendas desde o primeiro contato até o fechamento',
    stages: {
      prospeccao: {
        name: 'Prospecção',
        color: '#6366f1',
        position: 1,
        description: 'Leads e primeiros contatos',
        message_templates: [
          {
            id: `template_${Date.now()}_1`,
            title: 'Boas vindas',
            content: 'Olá! Obrigado por entrar em contato. Como posso ajudar?',
            webhook: {
              url: '',
              method: 'POST',
              enabled: false,
            },
            stage_id: 'prospeccao',
            conditions: {
              rules: [],
              enabled: false,
            },
            created_at: new Date().toISOString(),
          },
        ],
      },
      qualificacao: {
        name: 'Qualificação',
        color: '#8b5cf6',
        position: 2,
        description: 'Análise de fit',
        message_templates: [
          {
            id: `template_${Date.now()}_2`,
            title: 'Agendamento de Reunião',
            content:
              'Podemos agendar uma reunião para entender melhor suas necessidades?',
            webhook: { url: '', method: 'POST', enabled: false },
            stage_id: 'qualificacao',
            conditions: { rules: [], enabled: false },
            created_at: new Date().toISOString(),
          },
        ],
      },
      proposta: {
        name: 'Proposta',
        color: '#ec4899',
        position: 3,
        description: 'Envio e negociação',
      },
      fechamento: {
        name: 'Fechamento',
        color: '#10b981',
        position: 4,
        description: 'Contratos e pagamentos',
      },
    },
  },
  {
    id: 'support',
    name: 'Funil de Suporte',
    icon: 'chat',
    description: 'Atendimento e resolução de tickets de suporte',
    stages: {
      novo: {
        name: 'Novo',
        color: '#6366f1',
        position: 1,
        description: 'Tickets recém abertos',
        message_templates: [
          {
            id: `template_${Date.now()}_3`,
            title: 'Confirmação de Recebimento',
            content: 'Recebemos seu ticket. Nossa equipe já está analisando.',
            webhook: { url: '', method: 'POST', enabled: false },
            stage_id: 'novo',
            conditions: { rules: [], enabled: false },
            created_at: new Date().toISOString(),
          },
        ],
      },
      analise: {
        name: 'Em Análise',
        color: '#8b5cf6',
        position: 2,
        description: 'Avaliação técnica',
        message_templates: [
          {
            id: `template_${Date.now()}_4`,
            title: 'Atualização de Status',
            content: 'Seu ticket está em análise pela nossa equipe técnica.',
            webhook: { url: '', method: 'POST', enabled: false },
            stage_id: 'analise',
            conditions: { rules: [], enabled: false },
            created_at: new Date().toISOString(),
          },
        ],
      },
      desenvolvimento: {
        name: 'Em Desenvolvimento',
        color: '#ec4899',
        position: 3,
        description: 'Correção em andamento',
      },
      teste: {
        name: 'Em Teste',
        color: '#f59e0b',
        position: 4,
        description: 'Validação da solução',
      },
      resolvido: {
        name: 'Resolvido',
        color: '#10b981',
        position: 5,
        description: 'Ticket finalizado',
      },
    },
  },
  {
    id: 'recruitment',
    name: 'Funil de Recrutamento',
    icon: 'people',
    description: 'Processo seletivo e contratação',
    stages: {
      triagem: {
        name: 'Triagem',
        color: '#6366f1',
        position: 1,
        description: 'Análise de currículos',
      },
      entrevista: {
        name: 'Entrevista',
        color: '#8b5cf6',
        position: 2,
        description: 'Conversa inicial',
      },
      teste: {
        name: 'Teste Técnico',
        color: '#ec4899',
        position: 3,
        description: 'Avaliação prática',
      },
      proposta: {
        name: 'Proposta',
        color: '#10b981',
        position: 4,
        description: 'Negociação final',
      },
    },
  },
];

const handleTemplateSelect = template => {
  console.log('Template selecionado:', template);

  // Formata o template igual ao formato de edição
  const formattedTemplate = {
    name: template.name,
    description: template.description,
    stages: Object.entries(template.stages).reduce(
      (acc, [id, stage]) => ({
        ...acc,
        [id]: {
          ...stage,
          id,
          message_templates: stage.message_templates || [], // Preserva os templates existentes
          position: stage.position, // Garante que a posição é mantida
        },
      }),
      {}
    ),
    settings: {
      agents: [],
    },
  };

  // Ordena as etapas por posição
  const orderedStages = {};
  Object.entries(formattedTemplate.stages)
    .sort(([, a], [, b]) => a.position - b.position)
    .forEach(([id, stage]) => {
      orderedStages[id] = stage;
    });

  formattedTemplate.stages = orderedStages;

  console.log('Template formatado:', formattedTemplate);

  // Abre o modal com os dados formatados
  selectedTemplate.value = formattedTemplate;
  showTemplatesModal.value = false;
  showNewFunnelModal.value = true;
};

const handleBack = () => {
  emit('switch-view', 'kanban');
};

const handleFunnelCreated = funnel => {
  console.log('Funil criado:', funnel);
  showNewFunnelModal.value = false;
  emit('funnel-created', funnel);
};
</script>

<template>
  <header class="funnels-header">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-4">
        <button class="back-button" @click="handleBack">
          <fluent-icon
            icon="arrow-chevron-left"
            size="16"
            :icons="dashboardIcons"
          />
        </button>
        <h1 class="text-2xl font-medium">{{ t('KANBAN.FUNNELS.TITLE') }}</h1>
      </div>
      <div class="flex items-center gap-2">
        <woot-button
          variant="clear"
          size="small"
          @click="showTemplatesModal = true"
        >
          <fluent-icon
            icon="copy"
            size="20"
            :icons="dashboardIcons"
            class="mr-1"
          />
          <span>Modelos</span>
        </woot-button>
        <woot-button
          variant="primary"
          size="small"
          @click="showNewFunnelModal = true"
        >
          <fluent-icon
            icon="add"
            size="20"
            :icons="dashboardIcons"
            class="mr-1"
          />
          <span>{{ t('KANBAN.FUNNELS.ACTIONS.NEW') }}</span>
        </woot-button>
      </div>
    </div>

    <!-- Modal de Templates -->
    <Modal
      v-model:show="showTemplatesModal"
      :on-close="() => (showTemplatesModal = false)"
      size="medium"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.FUNNELS.TEMPLATES.TITLE') }}
        </h3>
        <div class="grid grid-cols-2 gap-4">
          <div
            v-for="template in funnelTemplates"
            :key="template.id"
            class="p-4 border rounded-lg hover:border-woot-500 cursor-pointer transition-colors"
            @click="handleTemplateSelect(template)"
          >
            <div class="flex items-center gap-2 mb-2">
              <fluent-icon
                :icon="template.icon"
                size="20"
                :icons="dashboardIcons"
                class="text-woot-500"
              />
              <h4 class="font-medium">{{ template.name }}</h4>
            </div>
            <p class="text-sm text-slate-600 dark:text-slate-400 mb-3">
              {{ template.description }}
            </p>
            <div class="flex flex-wrap gap-2">
              <span
                v-for="stage in Object.values(template.stages)"
                :key="stage.name"
                class="px-2 py-1 text-xs rounded-full"
                :style="{
                  backgroundColor: `${stage.color}20`,
                  color: stage.color,
                }"
              >
                {{ stage.name }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </Modal>

    <!-- Modal de Novo Funil -->
    <Modal
      v-model:show="showNewFunnelModal"
      :on-close="() => (showNewFunnelModal = false)"
      class="funnel-modal"
    >
      <div class="p-6">
        <h3 class="text-lg font-medium mb-4">
          {{ t('KANBAN.FUNNELS.ACTIONS.NEW') }}
        </h3>
        <FunnelForm
          :initial-data="selectedTemplate || emptyTemplate"
          @saved="handleFunnelCreated"
          @close="showNewFunnelModal = false"
        />
      </div>
    </Modal>
  </header>
</template>

<style lang="scss" scoped>
.funnels-header {
  padding: var(--space-normal);
  border-bottom: 1px solid var(--color-border);
  background: var(--white);

  @apply dark:border-slate-800 dark:bg-slate-900;

  h1 {
    @apply dark:text-slate-100;
  }
}

:deep(.funnel-modal) {
  .modal-container {
    @apply max-w-[1024px] w-[90vw] dark:bg-slate-900;

    h3 {
      @apply dark:text-slate-100;
    }
  }
}

.back-button {
  @apply p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 
    text-slate-700 dark:text-slate-300 transition-colors;
}
</style>
