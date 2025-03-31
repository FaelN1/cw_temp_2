<script setup>
import { computed, useSlots } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import Button from 'dashboard/components-next/button/Button.vue';
import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import ContactHistory from './ContactsSidebar/ContactHistory.vue';
import ContactKanbanHistory from './ContactsSidebar/ContactKanbanHistory.vue';
import ContactCustomAttributes from './ContactsSidebar/ContactCustomAttributes.vue';

const props = defineProps({
  buttonLabel: {
    type: String,
    default: '',
  },
  selectedContact: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['goToContactsList']);

const { t } = useI18n();
const slots = useSlots();
const route = useRoute();

const contactId = computed(() => route.params.contactId);

const selectedContactName = computed(() => {
  return props.selectedContact?.name;
});

const breadcrumbItems = computed(() => {
  const items = [
    {
      label: t('CONTACTS_LAYOUT.HEADER.BREADCRUMB.CONTACTS'),
      link: '#',
    },
  ];
  if (props.selectedContact) {
    items.push({
      label: selectedContactName.value,
    });
  }
  return items;
});

const handleBreadcrumbClick = () => {
  emit('goToContactsList');
};
</script>

<template>
  <section
    class="flex w-full h-full overflow-hidden justify-evenly bg-n-background"
  >
    <div
      class="flex flex-col w-full h-full transition-all duration-300 ltr:2xl:ml-56 rtl:2xl:mr-56"
    >
      <header class="sticky top-0 z-10 px-6 xl:px-0">
        <div class="w-full mx-auto max-w-[650px]">
          <div class="flex items-center justify-between w-full h-20 gap-2">
            <Breadcrumb
              :items="breadcrumbItems"
              @click="handleBreadcrumbClick"
            />
            <ComposeConversation :contact-id="contactId">
              <template #trigger="{ toggle }">
                <Button :label="buttonLabel" size="sm" @click="toggle" />
              </template>
            </ComposeConversation>
          </div>
        </div>
      </header>
      <main class="flex-1 px-6 overflow-y-auto xl:px-px">
        <div class="w-full py-4 mx-auto max-w-[650px]">
          <slot name="default" />
        </div>
      </main>
    </div>

    <div
      class="overflow-y-auto justify-end min-w-[200px] w-full py-6 max-w-[440px] border-l border-n-weak bg-n-solid-2"
    >
      <div class="flex flex-col">
        <div class="flex items-center px-6 mb-4">
          <div
            class="flex items-center gap-4 text-sm font-medium text-n-slate-12"
          >
            <button
              class="px-2 py-1 rounded-lg hover:bg-n-alpha-1"
              :class="{ 'bg-n-alpha-1': activeTab === 'history' }"
              @click="activeTab = 'history'"
            >
              {{ t('CONTACTS_LAYOUT.SIDEBAR.TABS.HISTORY') }}
            </button>
            <button
              class="px-2 py-1 rounded-lg hover:bg-n-alpha-1"
              :class="{ 'bg-n-alpha-1': activeTab === 'kanban' }"
              @click="activeTab = 'kanban'"
            >
              {{ t('CONTACTS_LAYOUT.SIDEBAR.TABS.KANBAN') }}
            </button>
            <button
              class="px-2 py-1 rounded-lg hover:bg-n-alpha-1"
              :class="{ 'bg-n-alpha-1': activeTab === 'attributes' }"
              @click="activeTab = 'attributes'"
            >
              {{ t('CONTACTS_LAYOUT.SIDEBAR.TABS.ATTRIBUTES') }}
            </button>
          </div>
        </div>

        <div v-if="activeTab === 'history'">
          <ContactHistory />
        </div>
        <div v-else-if="activeTab === 'kanban'">
          <ContactKanbanHistory />
        </div>
        <div v-else-if="activeTab === 'attributes'">
          <ContactCustomAttributes :selected-contact="selectedContact" />
        </div>
      </div>
    </div>
  </section>
</template>

<script>
// Adicione o estado para controlar a aba ativa
export default {
  data() {
    return {
      activeTab: 'history',
    };
  },
};
</script>
