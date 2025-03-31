<template>
  <Modal :show="show" :on-close="close" size="small">
    <div class="p-6">
      <h2 class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-4">
        {{ title }}
      </h2>

      <!-- Formulário para trigger -->
      <div v-if="nodeType === 'trigger'" class="trigger-editor">
        <!-- Campos comuns para todos os tipos de trigger -->
        <div class="form-group mb-4">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            Descrição (opcional)
          </label>
          <input
            v-model="formData.description"
            type="text"
            class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
            placeholder="descrição"
          />
        </div>

        <!-- Campos específicos para "message_received" -->
        <div v-if="triggerType === 'message_received'" class="trigger-fields">
          <div class="form-group mb-4">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Padrão de Texto (opcional)
            </label>
            <input
              v-model="formData.pattern"
              type="text"
              class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
              placeholder="ex: *ajuda*, #suporte"
            />
            <p class="text-xs text-slate-500 mt-1">
              Deixe em branco para qualquer mensagem
            </p>
          </div>
        </div>

        <!-- Campos específicos para "status_changed" -->
        <div v-if="triggerType === 'status_changed'" class="trigger-fields">
          <div class="form-group mb-4">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Status Anterior (opcional)
            </label>
            <input
              v-model="formData.fromStatus"
              type="text"
              class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
              placeholder="ex: pendente"
            />
          </div>

          <div class="form-group mb-4">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Novo Status
            </label>
            <input
              v-model="formData.toStatus"
              type="text"
              class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
              placeholder="ex: resolvido"
            />
          </div>
        </div>

        <!-- Campos específicos para "item_moved" -->
        <div v-if="triggerType === 'item_moved'" class="trigger-fields">
          <div class="form-group mb-4">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Coluna Anterior (opcional)
            </label>
            <input
              v-model="formData.fromColumn"
              type="text"
              class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
              placeholder="ex: Em Progresso"
            />
          </div>

          <div class="form-group mb-4">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Nova Coluna
            </label>
            <input
              v-model="formData.toColumn"
              type="text"
              class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
              placeholder="ex: Concluído"
            />
          </div>
        </div>

        <!-- Campos específicos para "scheduled" -->
        <div v-if="triggerType === 'scheduled'" class="trigger-fields">
          <div class="form-group mb-4">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Programação
            </label>
            <select
              v-model="formData.schedule"
              class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
            >
              <option value="daily">Diariamente</option>
              <option value="weekly">Semanalmente</option>
              <option value="monthly">Mensalmente</option>
            </select>
          </div>

          <div class="form-group mb-4">
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
            >
              Horário
            </label>
            <input
              v-model="formData.time"
              type="time"
              class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
            />
          </div>
        </div>
      </div>

      <!-- Formulário para condição -->
      <div v-else-if="nodeType === 'condition'" class="condition-editor">
        <div class="form-group mb-4">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            Campo
          </label>
          <input
            v-model="formData.field"
            type="text"
            class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
            placeholder="campo"
          />
        </div>

        <div class="form-group mb-4">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            Operador
          </label>
          <select
            v-model="formData.operator"
            class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
          >
            <option value="equals">igual a</option>
            <option value="not_equals">diferente de</option>
            <option value="contains">contém</option>
            <option value="greater_than">maior que</option>
            <option value="less_than">menor que</option>
          </select>
        </div>

        <div class="form-group mb-4">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            Valor
          </label>
          <input
            v-model="formData.value"
            type="text"
            class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
            placeholder="valor"
          />
        </div>

        <div class="form-group mb-4">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            Descrição (opcional)
          </label>
          <input
            v-model="formData.description"
            type="text"
            class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
            placeholder="descrição"
          />
        </div>
      </div>

      <!-- Formulário para ação -->
      <div v-else-if="nodeType === 'action'" class="action-editor">
        <!-- Campos específicos por tipo de ação -->
        <div v-if="actionType === 'send_message'" class="form-group mb-4">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            Mensagem
          </label>
          <textarea
            v-model="formData.message"
            class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
            rows="3"
            placeholder="Digite a mensagem a ser enviada"
          ></textarea>
        </div>

        <div
          v-if="
            actionType === 'change_status' || actionType === 'move_to_column'
          "
          class="form-group mb-4"
        >
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            Destino
          </label>
          <input
            v-model="formData.target"
            type="text"
            class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
            placeholder="Destino (status ou coluna)"
          />
        </div>

        <div class="form-group mb-4">
          <label
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
          >
            Descrição (opcional)
          </label>
          <input
            v-model="formData.description"
            type="text"
            class="w-full p-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800"
            placeholder="descrição"
          />
        </div>
      </div>

      <!-- Ações do modal -->
      <div class="flex justify-end gap-2">
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          @click="close"
        >
          Cancelar
        </woot-button>
        <woot-button
          variant="smooth"
          color-scheme="primary"
          size="small"
          @click="saveChanges"
        >
          Salvar
        </woot-button>
      </div>
    </div>
  </Modal>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useStore } from 'vuex';
import Modal from 'dashboard/components/Modal.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  nodeId: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(['close', 'save']);
const store = useStore();

// Dados do formulário expandidos para campos de trigger
const formData = ref({
  type: '',
  field: '',
  operator: 'equals',
  value: '',
  description: '',
  message: '',
  target: '',
  // Campos para triggers
  pattern: '',
  fromStatus: '',
  toStatus: '',
  fromColumn: '',
  toColumn: '',
  schedule: 'daily',
  time: '',
});

// Obter o nó do store
const node = computed(() => {
  if (!props.nodeId) return null;
  const nodes = store.state.automationFlow.flow.nodes;
  return nodes.find(n => n.id === props.nodeId);
});

// Tipo de nó
const nodeType = computed(() => {
  return node.value?.type || '';
});

// Tipo de ação
const actionType = computed(() => {
  return node.value?.data?.type || '';
});

// Tipo de trigger
const triggerType = computed(() => {
  return node.value?.data?.type || '';
});

// Título do modal baseado no tipo de nó
const title = computed(() => {
  if (nodeType.value === 'trigger') return 'Editar Disparador';
  if (nodeType.value === 'condition') return 'Editar Condição';
  if (nodeType.value === 'action') return 'Editar Ação';
  return 'Editar Nó';
});

// Carrega os dados do nó quando o componente é montado ou quando o nodeId muda
onMounted(() => {
  loadNodeData();
});

const loadNodeData = () => {
  if (!node.value) return;

  // Copia os dados existentes para o formulário
  const nodeData = node.value.data || {};
  formData.value = {
    type: nodeData.type || '',
    field: nodeData.field || '',
    operator: nodeData.operator || 'equals',
    value: nodeData.value || '',
    description: nodeData.description || '',
    message: nodeData.message || '',
    target: nodeData.target || '',
    label: nodeData.label || '',
    // Campos adicionais para triggers
    pattern: nodeData.pattern || '',
    fromStatus: nodeData.fromStatus || '',
    toStatus: nodeData.toStatus || '',
    fromColumn: nodeData.fromColumn || '',
    toColumn: nodeData.toColumn || '',
    schedule: nodeData.schedule || 'daily',
    time: nodeData.time || '',
  };
};

// Fecha o modal
const close = () => {
  emit('close');
};

// Salva as alterações
const saveChanges = () => {
  if (!node.value) return;

  // Atualiza o label com base no tipo, mantendo o tipo original
  let label = '';

  if (nodeType.value === 'trigger') {
    // Preservar o tipo original do trigger
    const originalType = node.value.data.type;
    formData.value.type = originalType;

    // Definir label baseado no tipo de trigger
    if (originalType === 'message_received') {
      label = 'Mensagem recebida';
    } else if (originalType === 'item_created') {
      label = 'Item criado';
    } else if (originalType === 'status_changed') {
      label = 'Status alterado';
    } else if (originalType === 'item_moved') {
      label = 'Item movido';
    } else if (originalType === 'scheduled') {
      label = 'Agendado';
    } else {
      label = originalType;
    }
  } else if (nodeType.value === 'condition') {
    label = 'Se';
    // Preservar o tipo original
    const originalType = node.value.data.type;
    formData.value.type = originalType;
  } else if (nodeType.value === 'action') {
    // Preservar o tipo original
    const originalType = node.value.data.type;
    formData.value.type = originalType;

    // Definir label baseado no tipo de ação
    if (originalType === 'send_message') {
      label = 'Enviar mensagem';
    } else if (originalType === 'change_status') {
      label = 'Alterar status';
    } else if (originalType === 'move_to_column') {
      label = 'Mover para coluna';
    } else if (originalType === 'assign_agent') {
      label = 'Atribuir a agente';
    } else if (originalType === 'add_label') {
      label = 'Adicionar etiqueta';
    } else if (originalType === 'change_priority') {
      label = 'Alterar prioridade';
    } else {
      label = originalType;
    }
  }

  // Atualiza os dados do nó no store
  store.dispatch('automationFlow/updateNodeData', {
    nodeId: props.nodeId,
    data: {
      ...formData.value,
      label,
    },
  });

  emit('save');
  close();
};
</script>
