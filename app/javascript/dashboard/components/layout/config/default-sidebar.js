import conversations from './sidebarItems/conversations';
import contacts from './sidebarItems/contacts';
import reports from './sidebarItems/reports';
import campaigns from './sidebarItems/campaigns';
import settings from './sidebarItems/settings';
import notifications from './sidebarItems/notifications';
import primaryMenu from './sidebarItems/primaryMenu';
import dashboardApps from './sidebarItems/dashboardApps';

export const getSidebarItems = accountId => ({
  primaryMenu: primaryMenu(accountId),
  secondaryMenu: [
    conversations(accountId),
    dashboardApps(accountId),
    contacts(accountId),
    reports(accountId),
    campaigns(accountId),
    settings(accountId),
    notifications(accountId),
  ],
});
