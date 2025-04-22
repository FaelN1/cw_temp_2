const CampaignHelper = {
  validateAudience(audience) {
    if (!audience || !Array.isArray(audience) || audience.length === 0) {
      console.error('Audiência inválida: deve ser um array não vazio');
      return false;
    }

    const hasInvalidItems = audience.some(item => {
      return !item.id || !item.type || !['Label'].includes(item.type);
    });

    if (hasInvalidItems) {
      console.error('Audiência inválida: cada item deve ter um id e um type válido (Label)');
      return false;
    }

    return true;
  },

  // Auxiliar para debug da audiência
  logAudienceDetails(audience) {
    if (!audience) {
      console.log('Audiência não definida');
      return;
    }

    console.log(`Audiência contém ${audience.length} itens:`);
    audience.forEach((item, index) => {
      console.log(`Item ${index + 1}: tipo=${item.type}, id=${item.id}`);
    });
  },

  // Auxiliar para preparar o objeto de campanha antes de enviar para a API
  prepareCampaignPayload(campaign) {
    const payload = { ...campaign };

    // Garantir que audience seja um array e tenha o formato correto
    if (payload.audience && Array.isArray(payload.audience)) {
      payload.audience = payload.audience.map(item => ({
        id: parseInt(item.id, 10),  // Garantir que id seja número
        type: item.type
      }));
    }

    return payload;
  }
};

export default CampaignHelper;
