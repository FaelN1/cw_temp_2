import LiveChatCampaignsPage from './pages/LiveChatCampaignsPage.vue';
import SMSCampaignsPage from './pages/SMSCampaignsPage.vue';
import WhatsappCampaignsPage from './pages/WhatsappCampaignsPage.vue';
import { frontendURL } from '../../../helper/URLHelper';

const campaignRoutes = [
  {
    path: frontendURL('accounts/:accountId/campaigns/livechat'),
    name: 'livechat_campaigns',
    roles: ['administrator', 'agent'],
    component: LiveChatCampaignsPage,
  },
  {
    path: frontendURL('accounts/:accountId/campaigns/sms'),
    name: 'sms_campaigns',
    roles: ['administrator', 'agent'],
    component: SMSCampaignsPage,
  },
  {
    path: frontendURL('accounts/:accountId/campaigns/whatsapp'),
    name: 'whatsapp_campaigns',
    roles: ['administrator', 'agent'],
    component: WhatsappCampaignsPage,
  },
];

export default campaignRoutes;
