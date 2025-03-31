import settings from './settings/settings.routes';
import conversation from './conversation/conversation.routes';
import { routes as searchRoutes } from '../../modules/search/search.routes';
import { routes as contactRoutes } from './contacts/routes';
import { routes as notificationRoutes } from './notifications/routes';
import { routes as inboxRoutes } from './inbox/routes';
import { frontendURL } from '../../helper/URLHelper';
import helpcenterRoutes from './helpcenter/helpcenter.routes';
import campaignsRoutes from './campaigns/campaigns.routes';

import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import AppContainer from './Dashboard.vue';
import Captain from './Captain.vue';
import Suspended from './suspended/Index.vue';
import KanbanView from './kanban/KanbanView.vue';
import DashboardAppWrapper from './dashboard-apps/DashboardAppWrapper.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId'),
      component: AppContainer,
      children: [
        {
          path: frontendURL('accounts/:accountId/dashboard_apps/:id'),
          name: 'dashboard_apps_show',
          component: DashboardAppWrapper,
          meta: {
            permissions: ['administrator', 'agent'],
            icon: 'i-lucide-apps',
            label: 'DASHBOARD_APPS',
          },
          props: true,
        },
        {
          path: frontendURL('accounts/:accountId/captain/:page'),
          name: 'captain',
          component: Captain,
          meta: {
            permissions: ['administrator', 'agent'],
            featureFlag: FEATURE_FLAGS.CAPTAIN,
          },
          props: true,
        },
        {
          path: frontendURL('accounts/:accountId/kanban'),
          name: 'kanban_board',
          component: KanbanView,
          meta: {
            permissions: [
              'administrator',
              'agent',
              'kanban_manage',
              'kanban_view',
            ],
            featureFlag: FEATURE_FLAGS.KANBAN_BOARD,
          },
        },
        ...inboxRoutes,
        ...conversation.routes,
        ...settings.routes,
        ...contactRoutes,
        ...searchRoutes,
        ...notificationRoutes,
        ...helpcenterRoutes.routes,
        ...campaignsRoutes.routes,
      ],
    },
    {
      path: frontendURL('accounts/:accountId/suspended'),
      name: 'account_suspended',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: Suspended,
    },
  ],
};
