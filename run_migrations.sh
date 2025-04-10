#!/bin/bash
echo "Executando migrações pendentes..."
bundle exec rails db:migrate
echo "Migrações concluídas!"
