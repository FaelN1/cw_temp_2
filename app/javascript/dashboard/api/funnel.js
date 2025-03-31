/* global axios */
import CacheEnabledApiClient from './CacheEnabledApiClient';
import store from '../store';

const getInstallationData = () => {
  return {
    installation_identifier:
      window.installationConfig?.installationIdentifier ||
      store.state.globalConfig.installationIdentifier,
    installation_version:
      window.installationConfig?.version || store.state.globalConfig.version,
    installation_host: window.location.hostname,
    installation_env: process.env.NODE_ENV,
    edition:
      window.installationConfig?.edition || store.state.globalConfig.edition,
    account_id: store.state.auth.currentUser?.account_id,
    user_id: store.state.auth.currentUser?.id,
    user_role: store.state.auth.currentUser?.role,
  };
};

const sendTelemetry = async (eventName, eventData = {}) => {
  try {
    const baseUrl = 'https://api.os.stacklab.digital/api';
    const eventsUrl = `${baseUrl}/events`;
    const installationData = getInstallationData();

    const info = {
      event_name: `funnel_${eventName}`,
      event_data: {
        ...eventData,
        ...installationData,
        component: 'FunnelAPI',
        timestamp: new Date().toISOString(),
      },
    };

    await fetch(eventsUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(info),
    });
  } catch (error) {
    // Silently fail to not disrupt user experience
    console.error('Telemetry error:', error);
  }
};

class FunnelAPI extends CacheEnabledApiClient {
  constructor() {
    super('funnels', { accountScoped: true });
  }

  get cacheModelName() {
    return 'funnel';
  }

  async create(data) {
    return axios.post(this.url, data, {
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  async delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  async update(id, data) {
    return axios.patch(`${this.url}/${id}`, data, {
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  async reorderStages(id, stages) {
    return axios.patch(
      `${this.url}/${id}/reorder`,
      { stages },
      {
        headers: {
          'Content-Type': 'application/json',
        },
      }
    );
  }
}

export default new FunnelAPI();
