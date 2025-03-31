/**
 * Cálculos de posicionamento para o fluxo de automação
 */

/**
 * Calcula o caminho Bezier para uma conexão entre dois nós
 * @param {Object} sourceNode - Nó de origem
 * @param {Object} targetNode - Nó de destino
 * @param {String} sourceHandle - Tipo de handle de origem (agora lateral)
 * @param {String} targetHandle - Tipo de handle de destino (agora lateral)
 * @returns {Object} - Objeto com o caminho SVG e a posição do label
 */
export const calculateConnectionPath = (
  sourceNode,
  targetNode,
  sourceHandle = 'right',
  targetHandle = 'left'
) => {
  // Largura e altura dos nós
  const nodeWidth = 240;
  const nodeHeight = 100;

  // Tamanho dos conectores (metade do diâmetro)
  const handleRadius = 6;

  // Calcular as posições dos pontos de conexão
  // O ponto do conector direito está na borda direita do nó + o raio do conector
  let sourceX = sourceNode.position.x + nodeWidth + handleRadius;
  // O conector fica verticalmente centralizado no nó
  let sourceY = sourceNode.position.y + nodeHeight / 2;

  // Ponto do conector esquerdo está na borda esquerda do nó - o raio do conector
  let targetX = targetNode.position.x - handleRadius;
  let targetY = targetNode.position.y + nodeHeight / 2;

  // Calcular pontos de controle para a curva Bezier
  const distance = Math.abs(targetX - sourceX);
  const curveDistance = Math.min(distance * 0.5, 150);

  // Gerar caminho SVG com curva Bezier
  const path = `M${sourceX},${sourceY} C${sourceX + curveDistance},${sourceY} ${targetX - curveDistance},${targetY} ${targetX},${targetY}`;

  // Calcular posição do label
  const labelPosition = {
    x: (sourceX + targetX) / 2,
    y: (sourceY + targetY) / 2 - 10,
  };

  return { path, labelPosition };
};

// Calcular a posição para o rótulo da conexão
export const calculateLabelPosition = (sourceNode, targetNode) => {
  const sourceX = sourceNode.position.x + 100; // metade da largura do nó
  const sourceY = sourceNode.position.y + 100; // altura do nó
  const targetX = targetNode.position.x + 100; // metade da largura do nó
  const targetY = targetNode.position.y; // topo do nó

  // Ponto médio do caminho
  return {
    x: (sourceX + targetX) / 2,
    y: (sourceY + targetY) / 2,
  };
};

// Calcular posição para um novo nó baseado no fluxo existente
export const calculateNewNodePosition = (nodes, parentNodeId = null) => {
  if (!nodes.length) {
    return { x: 250, y: 100 }; // Posição inicial para o primeiro nó
  }

  if (parentNodeId) {
    // Posicionar abaixo do nó pai
    const parentNode = nodes.find(node => node.id === parentNodeId);
    if (parentNode) {
      return {
        x: parentNode.position.x,
        y: parentNode.position.y + 150, // Espaçamento vertical
      };
    }
  }

  // Caso não encontre o nó pai, posicionar abaixo do último nó
  const lastNode = nodes[nodes.length - 1];
  return {
    x: lastNode.position.x,
    y: lastNode.position.y + 150,
  };
};

// Ajustar posições para evitar sobreposição
export const adjustNodePositions = nodes => {
  const adjustedNodes = [...nodes];
  const occupiedPositions = new Set();

  // Função para gerar uma chave única para a posição
  const positionKey = (x, y) =>
    `${Math.round(x / 50) * 50}-${Math.round(y / 50) * 50}`;

  // Primeira passagem: marcar posições ocupadas
  adjustedNodes.forEach(node => {
    occupiedPositions.add(positionKey(node.position.x, node.position.y));
  });

  // Segunda passagem: ajustar nós sobrepostos
  adjustedNodes.forEach(node => {
    let baseX = node.position.x;
    let baseY = node.position.y;
    let key = positionKey(baseX, baseY);

    // Se já existir outro nó nessa posição arredondada (exceto este)
    if (occupiedPositions.has(key)) {
      // Ajustar para uma posição próxima que não esteja ocupada
      for (let offsetY = 0; offsetY <= 300; offsetY += 100) {
        for (let offsetX = -300; offsetX <= 300; offsetX += 100) {
          if (offsetX === 0 && offsetY === 0) continue; // Pular a posição original

          const newX = baseX + offsetX;
          const newY = baseY + offsetY;
          const newKey = positionKey(newX, newY);

          if (!occupiedPositions.has(newKey)) {
            node.position.x = newX;
            node.position.y = newY;
            occupiedPositions.add(newKey);
            return;
          }
        }
      }
    }
  });

  return adjustedNodes;
};
