import Dashboard from './Dashboard';
import conversationRoutes from './conversation/routes';
import contactRoutes from './contacts/routes';
import notificationRoutes from './notifications/routes';
import settingsRoutes from './settings/routes';
import campaignRoutes from './campaign/routes';
import reportRoutes from './reports/routes';
import helpCenterRoutes from './helpcenter/routes';
import dashboardAppsRoutes from './dashboard-apps/routes';

const routes = [
  {
    path: 'accounts/:accountId',
    component: Dashboard,
    children: [
      ...conversationRoutes.routes,
      ...contactRoutes.routes,
      ...notificationRoutes.routes,
      ...settingsRoutes.routes,
      ...campaignRoutes.routes,
      ...reportRoutes.routes,
      ...helpCenterRoutes.routes,
      ...dashboardAppsRoutes.routes,
    ],
  },
];

export default routes;
