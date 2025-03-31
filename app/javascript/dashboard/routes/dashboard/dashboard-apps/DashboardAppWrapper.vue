<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';

const route = useRoute();
const store = useStore();
const iframeRef = ref(null);

const dashboardApp = computed(() => {
  const appId = route.params.id;
  return store.getters['dashboardApps/getRecords'].find(
    app => app.id === Number(appId)
  );
});

const isTypebot = computed(() => {
  return dashboardApp.value?.content?.some(
    item => item.model_app === 'typebot'
  );
});

const appUrl = computed(() => {
  if (!dashboardApp.value?.content?.[0]?.url) return '';
  return dashboardApp.value.content[0].url;
});

const fillTypebotEmail = () => {
  if (!isTypebot.value || !iframeRef.value) return;

  setTimeout(() => {
    try {
      const iframe = iframeRef.value;
      const email = store.getters['auth/currentUser']?.email || '';

      // Tenta acessar o documento do iframe (pode falhar devido a restrições de segurança)
      try {
        const doc = iframe.contentDocument || iframe.contentWindow.document;
        const emailInput = doc.querySelector('input[name="email"]');
        if (emailInput) {
          emailInput.value = email;
          emailInput.dispatchEvent(new Event('input', { bubbles: true }));
        }
      } catch (error) {
        // Alternativa usando postMessage
        iframe.contentWindow.postMessage(
          {
            action: 'fill_email',
            email: email,
          },
          '*'
        );
      }
    } catch (e) {
      console.error('Erro ao preencher email no Typebot:', e);
    }
  }, 1500);
};

onMounted(() => {
  if (!store.getters['dashboardApps/getRecords'].length) {
    store.dispatch('dashboardApps/get');
  }
});

const onIframeLoad = () => {
  if (isTypebot.value) {
    fillTypebotEmail();
  }
};
</script>

<template>
  <div class="h-full w-full flex-1 overflow-hidden">
    <iframe
      v-if="appUrl"
      :src="appUrl"
      class="h-full w-full border-0"
      :title="dashboardApp?.title"
      ref="iframeRef"
      @load="onIframeLoad"
    />
    <div
      v-else
      class="h-full w-full flex items-center justify-center text-slate-500"
    >
      {{ $t('INTEGRATION_SETTINGS.DASHBOARD_APPS.LOADING') }}
    </div>
  </div>
</template>
