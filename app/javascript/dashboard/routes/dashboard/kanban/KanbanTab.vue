const handleDelete = async itemToDeleteParam => { try { isUpdating.value = true;
await KanbanAPI.deleteItem(itemToDeleteParam.id);
emitter.emit('newToastMessage', { message: 'Item excluído com sucesso', action:
{ type: 'success' }, }); showDeleteModal.value = false; itemToDelete.value =
null; } catch (err) { emitter.emit('newToastMessage', { message:
err.response?.data?.message || t('KANBAN.ERROR_DELETING_ITEM'), action: { type:
'error' }, }); } finally { isUpdating.value = false; } }; // Continuar com o
resto do handleDrop const handleDrop = async (itemId, columnId) => { try {
isUpdating.value = true; console.log('[ORDENAÇÃO-DROP] Iniciando drag/drop de
item:', itemId, 'para coluna:', columnId); // Chamada ao store para mover o item
await store.dispatch('kanban/moveItemToStage', { itemId: parseInt(itemId, 10),
columnId, }); // Verificar a ordem original dos stages const funnel =
store.getters['funnel/getSelectedFunnel']; if (funnel?.stages) {
console.log('[ORDENAÇÃO-DROP] Ordem original dos estágios:');
Object.entries(funnel.stages).forEach(([id, stage]) => { console.log(`Estágio:
${stage.name}, ID: ${id}, Posição: ${stage.position}`); }); } // Atualiza as
colunas mantendo a ordem original do objeto stages nextTick(() => {
console.log('[ORDENAÇÃO-DROP] Atualizando colunas mantendo ordem original...');
updateColumns(); }); emitter.emit('newToastMessage', { message: 'Item movido com
sucesso', action: { type: 'success' }, }); } catch (err) {
console.error('[ORDENAÇÃO-DROP] Erro ao mover item:', err);
emitter.emit('newToastMessage', { message: err.response?.data?.message ||
t('KANBAN.ERROR_MOVING_ITEM'), action: { type: 'error' }, }); } finally {
isUpdating.value = false; console.log('[ORDENAÇÃO-DROP] Finalizado.'); } }; //
Para os outros métodos const handleAddSubmit = async data => { await
createItem(data); showAddModal.value = false; selectedColumn.value = null; };
const handleDetailsUpdate = () => { // Não precisa de atualização aqui }; const
handleEditSubmit = async data => { await updateItem(data.id, data);
showEditModal.value = false; itemToEdit.value = null; };
