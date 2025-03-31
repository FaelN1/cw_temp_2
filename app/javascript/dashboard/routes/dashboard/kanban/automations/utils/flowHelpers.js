import { calculateNewNodePosition } from './flowPositioning';

// Inicializa o flow no store (quando carrega uma automação existente ou cria uma nova)
export const initializeFlow = (store, flowData = null) => {
  if (flowData && flowData.nodes && flowData.connections) {
    // Carregar flow existente
    store.dispatch('automationFlow/initFlow', flowData);
  } else {
    // Iniciar um novo flow com um nó trigger padrão
    store.dispatch('automationFlow/initFlow');
  }
};

// Exporta o flow atual para salvar
export const exportFlow = store => {
  const nodes = store.state.automationFlow.flow.nodes;
  const connections = store.state.automationFlow.flow.connections;

  return {
    nodes,
    connections,
  };
};

// Adiciona um novo nó ao flow
export const addNode = (store, { type, parentNodeId = null, data = {} }) => {
  const nodes = store.state.automationFlow.flow.nodes;
  const position = calculateNewNodePosition(nodes, parentNodeId);

  // Configurar dados específicos para cada tipo de nó
  let nodeData = { ...data };

  switch (type) {
    case 'trigger':
      nodeData = {
        label: 'Novo Trigger',
        type: 'message_received',
        ...data,
      };
      break;
    case 'condition':
      nodeData = {
        label: 'Condição',
        field: '',
        operator: '==',
        value: '',
        ...data,
      };
      break;
    case 'action':
      nodeData = {
        label: 'Nova Ação',
        type: 'send_message',
        ...data,
      };
      break;
  }

  // Criar o nó
  const nodeId = store.dispatch('automationFlow/createNode', {
    type,
    position,
    data: nodeData,
  });

  // Se houver um nó pai, criar conexão automática
  if (parentNodeId) {
    store.dispatch('automationFlow/connectNodes', {
      sourceId: parentNodeId,
      targetId: nodeId,
    });
  }

  return nodeId;
};

// Valida o flow para garantir que está correto antes de salvar
export const validateFlow = store => {
  const nodes = store.state.automationFlow.flow.nodes;
  const connections = store.state.automationFlow.flow.connections;

  const errors = [];

  // Verificar se tem pelo menos um nó trigger
  const triggerNodes = nodes.filter(node => node.type === 'trigger');
  if (triggerNodes.length === 0) {
    errors.push('O fluxo precisa ter pelo menos um nó de trigger');
  }

  // Verificar se todos os nós estão conectados
  const connectedNodeIds = new Set();
  connections.forEach(conn => {
    connectedNodeIds.add(conn.source);
    connectedNodeIds.add(conn.target);
  });

  const disconnectedNodes = nodes.filter(
    node => !connectedNodeIds.has(node.id) && node.type !== 'trigger'
  );
  if (disconnectedNodes.length > 0) {
    errors.push(`Existem ${disconnectedNodes.length} nós desconectados`);
  }

  return { isValid: errors.length === 0, errors };
};

// Executa o flow (para teste ou simulação)
export const executeFlow = async (store, context = {}) => {
  const nodes = store.state.automationFlow.flow.nodes;
  const connections = store.state.automationFlow.flow.connections;

  // Encontrar nós de trigger para começar a execução
  const triggerNodes = nodes.filter(node => node.type === 'trigger');

  if (triggerNodes.length === 0)
    return { success: false, error: 'Nenhum nó de trigger encontrado' };

  // Iniciar a execução pelo primeiro trigger
  const results = [];
  const visited = new Set();

  for (const triggerNode of triggerNodes) {
    const result = await executeNode(triggerNode.id, store, context, visited);
    results.push(result);
  }

  return { success: true, results };
};

// Executa um nó específico e seus nós filhos
const executeNode = async (nodeId, store, context, visited = new Set()) => {
  if (visited.has(nodeId)) return null; // Evitar loops infinitos

  visited.add(nodeId);

  const nodes = store.state.automationFlow.flow.nodes;
  const connections = store.state.automationFlow.flow.connections;

  const node = nodes.find(n => n.id === nodeId);
  if (!node) return null;

  let result;

  // Executar com base no tipo do nó
  switch (node.type) {
    case 'trigger':
      // Trigger apenas inicia o fluxo
      result = { triggered: true };
      break;

    case 'condition':
      // Avaliar a condição
      result = evaluateCondition(node.data, context);
      break;

    case 'action':
      // Executar a ação
      result = await executeAction(node.data, context);
      break;

    default:
      result = null;
  }

  // Encontrar nós filhos conectados
  const childConnections = connections.filter(conn => conn.source === nodeId);

  // Executar nós filhos com base no resultado
  for (const conn of childConnections) {
    // Para condições, verificar o resultado antes de seguir
    if (node.type === 'condition') {
      const isTrue = result === true;

      // Verificar se a conexão tem um label que corresponde ao resultado
      const shouldFollow =
        (isTrue && conn.label === 'true') ||
        (!isTrue && conn.label === 'false') ||
        !conn.label; // Se não tiver label, seguir sempre

      if (!shouldFollow) continue;
    }

    // Seguir para o próximo nó
    await executeNode(conn.target, store, { ...context, result }, visited);
  }

  return result;
};

// Avalia uma condição
const evaluateCondition = (conditionData, context) => {
  const { field, operator, value } = conditionData;

  // Obter o valor do campo do contexto
  const fieldValue = field
    .split('.')
    .reduce((obj, prop) => obj && obj[prop], context);

  // Se o campo não existir no contexto
  if (fieldValue === undefined) return false;

  // Avaliar com base no operador
  switch (operator) {
    case '==':
      return fieldValue == value;
    case '!=':
      return fieldValue != value;
    case '>':
      return fieldValue > value;
    case '>=':
      return fieldValue >= value;
    case '<':
      return fieldValue < value;
    case '<=':
      return fieldValue <= value;
    case 'contains':
      return String(fieldValue).includes(String(value));
    case 'not_contains':
      return !String(fieldValue).includes(String(value));
    case 'is_empty':
      return !fieldValue || fieldValue.length === 0;
    case 'is_not_empty':
      return fieldValue && fieldValue.length > 0;
    default:
      return false;
  }
};

// Executa uma ação
const executeAction = async (actionData, context) => {
  const { type } = actionData;

  // Executar com base no tipo de ação
  switch (type) {
    case 'move_to_column':
      // Implementação para mover para coluna
      return {
        success: true,
        action: 'move_to_column',
        column: actionData.column,
      };

    case 'change_priority':
      // Implementação para mudar prioridade
      return {
        success: true,
        action: 'change_priority',
        priority: actionData.priority,
      };

    case 'assign_agent':
      // Implementação para atribuir agente
      return {
        success: true,
        action: 'assign_agent',
        agentId: actionData.agent_id,
      };

    case 'send_message':
      // Implementação para enviar mensagem
      return {
        success: true,
        action: 'send_message',
        message: actionData.message,
      };

    case 'add_label':
      // Implementação para adicionar etiqueta
      return { success: true, action: 'add_label', label: actionData.label };

    default:
      return { success: false, error: `Tipo de ação desconhecido: ${type}` };
  }
};
