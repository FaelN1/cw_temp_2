<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Modal from '../../../../components/Modal.vue';

const store = useStore();
const { t } = useI18n();
const isDropdownOpen = ref(false);
const showModal = ref(false);
const isMobile = ref(window.innerWidth < 768);

const funnels = computed(() => store.getters['funnel/getFunnels']);
const selectedFunnel = computed(
  () => store.getters['funnel/getSelectedFunnel']
);
const uiFlags = computed(() => store.getters['funnel/getUIFlags']);

const toggleDropdown = () => {
  if (isMobile.value) {
    showModal.value = true;
  } else {
    isDropdownOpen.value = !isDropdownOpen.value;
  }
};

const selectFunnel = async funnel => {
  try {
    await store.dispatch('funnel/setSelectedFunnel', funnel);
    isDropdownOpen.value = false;
    showModal.value = false;
  } catch (error) {
    // Notifica o usuário sobre o erro
    store.dispatch('notifications/show', {
      type: 'error',
      message: t('KANBAN.ERRORS.FUNNEL_SELECTION_FAILED'),
    });
  }
};

// Atualiza o estado mobile quando a janela é redimensionada
const handleResize = () => {
  isMobile.value = window.innerWidth < 768;
};

onMounted(async () => {
  try {
    await store.dispatch('funnel/fetch');

    // Se não houver funil selecionado e existirem funis, seleciona o primeiro
    if (!selectedFunnel.value && funnels.value.length > 0) {
      await selectFunnel(funnels.value[0]);
    }

    window.addEventListener('resize', handleResize);
  } catch (error) {
    // Notifica o usuário sobre o erro
    store.dispatch('notifications/show', {
      type: 'error',
      message: t('KANBAN.ERRORS.FUNNEL_FETCH_FAILED'),
    });
  }
});
</script>

<template>
  <div class="funnel-selector">
    <woot-button
      type="button"
      variant="clear"
      size="small"
      class="funnel-button"
      :disabled="uiFlags.isFetching"
      @click="toggleDropdown"
    >
      <fluent-icon icon="task" size="16" class="mr-1 md:mr-1 mr-0" />
      <template v-if="uiFlags.isFetching">
        <span class="md:inline hidden">{{ $t('KANBAN.LOADING_FUNNELS') }}</span>
      </template>
      <template v-else>
        <span class="md:inline hidden">{{
          selectedFunnel ? selectedFunnel.name : $t('KANBAN.SELECT_FUNNEL')
        }}</span>
      </template>
      <fluent-icon
        icon="chevron-down"
        size="16"
        class="md:inline hidden ml-1"
      />
    </woot-button>

    <!-- Dropdown para desktop -->
    <div v-if="isDropdownOpen && !isMobile" class="dropdown-menu">
      <div
        v-for="funnel in funnels"
        :key="funnel.id"
        class="dropdown-item"
        :class="{ active: selectedFunnel?.id === funnel.id }"
        @click="selectFunnel(funnel)"
      >
        {{ funnel.name }}
      </div>
    </div>

    <!-- Modal para mobile -->
    <Modal
      v-model:show="showModal"
      :on-close="() => (showModal = false)"
      size="small"
    >
      <div class="p-4">
        <h3 class="text-lg font-medium mb-3">Selecionar Funil</h3>
        <div class="funnel-list">
          <button
            v-for="funnel in funnels"
            :key="funnel.id"
            class="funnel-option"
            :class="{ 'funnel-active': selectedFunnel?.id === funnel.id }"
            @click="selectFunnel(funnel)"
          >
            <fluent-icon icon="task" size="18" class="mr-2" />
            <div class="funnel-name">
              {{ funnel.name }}
            </div>
            <fluent-icon
              v-if="selectedFunnel?.id === funnel.id"
              icon="checkmark"
              size="16"
              class="ml-auto text-woot-500"
            />
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>

<style lang="scss" scoped>
.funnel-selector {
  position: relative;
  display: inline-block;
}

.funnel-button {
  display: flex;
  align-items: center;
  gap: var(--space-micro);
  padding: var(--space-small);
  border: 1px solid var(--color-woot);
  border-radius: var(--border-radius-normal);
  background: var(--white);
  color: var(--color-woot);

  @apply dark:bg-slate-800 dark:border-woot-600 dark:text-woot-500;

  @media (max-width: 768px) {
    padding: 0.375rem;
    min-width: 36px;
    justify-content: center;
  }

  &:hover {
    background: var(--color-background);
    border-color: var(--color-woot);
    opacity: 0.8;

    @apply dark:bg-slate-700 dark:border-woot-500;
  }
}

.dropdown-menu {
  position: absolute;
  top: 100%;
  left: 0;
  z-index: 9995;
  min-width: 200px;
  margin-top: var(--space-micro);
  padding: var(--space-micro);
  background: var(--white);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-normal);
  box-shadow: var(--shadow-dropdown);

  @apply dark:bg-slate-800 dark:border-slate-700;
}

.dropdown-item {
  padding: var(--space-small) var(--space-normal);
  cursor: pointer;
  border-radius: var(--border-radius-small);
  @apply dark:text-slate-100;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;

  &:hover {
    background: var(--color-background);
    @apply dark:bg-slate-700;
  }

  &.active {
    background: var(--color-background);
    color: var(--color-woot);

    @apply dark:bg-slate-700 dark:text-woot-500;
  }
}

// Estilos para as opções no modal móvel
.funnel-list {
  @apply flex flex-col gap-2 max-h-[50vh] overflow-y-auto;
}

.funnel-option {
  @apply flex items-center p-3 rounded-lg text-left w-full;
  @apply text-slate-700 dark:text-slate-200;
  @apply hover:bg-slate-50 dark:hover:bg-slate-700;
  @apply transition-colors duration-150;

  .funnel-name {
    @apply font-medium;
    word-break: break-word;
  }

  &.funnel-active {
    @apply bg-woot-50 text-woot-600 dark:bg-woot-900/20 dark:text-woot-300;
  }
}
</style>
