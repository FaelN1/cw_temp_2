#!/bin/bash
echo "Configurando CHATWOOT_CLOUD_PLANS com valores padrão"

export CHATWOOT_CLOUD_PLANS='[{"name":"Pro","default_quantity":10,"product_id":"prod_RpWZqcSx3tExrW","price_ids":"price_1QvrWfGnu5TnL43dhMmwjvST"}]'

echo "Valor configurado: $CHATWOOT_CLOUD_PLANS"
echo "Reinicie a aplicação para que as alterações tenham efeito."
