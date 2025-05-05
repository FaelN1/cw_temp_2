# Configuração do Banco de Dados

Para preparar corretamente o banco de dados, execute os comandos na seguinte ordem:

```bash
# Primeiro, execute as migrações para criar as funções SQL necessárias
bundle exec rails db:migrate

# Em seguida, execute o comando de preparação do Chatwoot
bundle exec rails db:chatwoot_prepare
```

Se ainda encontrar problemas com funções SQL ausentes, tente recriar o banco de dados:

```bash
bundle exec rails db:drop db:create db:migrate db:chatwoot_prepare db:seed
```

## Solucionando problemas comuns

### Erros de função existente durante migrações

Se encontrar erros como "cannot change return type of existing function", pode ser necessário executar o seguinte comando para verificar e remover funções conflitantes:

```bash
# Validar e corrigir as migrações com erros específicos
bundle exec rails db:migrate:up VERSION=YYYYMMDDHHMMSS
```

Substitua YYYYMMDDHHMMSS pelo número da versão da migração específica que está causando o problema.
