import { frontendURL } from '../../../../helper/URLHelper';

const dashboardApps = accountId => ({
  parentNav: 'dashboardApps',
  routes: ['dashboard_apps_show', 'dashboard_apps_index'],
  menuItems: [],
  getMenuItems: apps => {
    return apps
      .filter(app => app.show_in_navigation)
      .map(app => ({
        icon: 'link',
        label: app.title,
        key: `app_${app.id}`,
        toState: frontendURL(`accounts/${accountId}/dashboard_apps/${app.id}`),
        toStateName: 'dashboard_apps_show',
      }));
  },
});

export default dashboardApps;
