import CacheEnabledApiClient from './CacheEnabledApiClient';

class LabelsAPI extends CacheEnabledApiClient {
  constructor() {
    super('labels', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'label';
  }

  // Adicione este método para buscar labels com cores
  async getLabelColors() {
    const { data } = await this.get();
    return data.payload.reduce((acc, label) => {
      acc[label.title] = label.color;
      return acc;
    }, {});
  }
}

export default new LabelsAPI();
