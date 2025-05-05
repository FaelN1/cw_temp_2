namespace :account_users do
  desc "Diagnosticar e corrigir problemas com os roles de AccountUser"
  task fix_roles: :environment do
    puts "Iniciando diagnóstico de AccountUser roles..."
    puts "Roles definidos: #{AccountUser.roles.inspect}"

    # Contar roles atuais para diagnóstico
    admin_count_before = AccountUser.where(role: 1).count
    agent_count_before = AccountUser.where(role: 0).count
    puts "Status atual: #{admin_count_before} administradores, #{agent_count_before} agentes"

    # Verificar usuarios com problemas
    account_users_to_fix = AccountUser.all.select do |au|
      (au.role_before_type_cast == 1 && !au.administrator?) ||
      (au.role_before_type_cast == 0 && !au.agent?)
    end

    puts "Encontrados #{account_users_to_fix.count} registros com inconsistências de role"

    # Listar alguns exemplos para verificação
    puts "\nExemplos de registros problemáticos:"
    account_users_to_fix.limit(5).each do |au|
      puts "ID: #{au.id}, User: #{au.user_id}, Account: #{au.account_id}, Role_raw: #{au.role_before_type_cast}, Role_symbol: #{au.role}, administrator?: #{au.administrator?}"
    end

    # Confirmar correção
    puts "\nDeseja corrigir estes registros? (y/n)"
    response = STDIN.gets.chomp.downcase

    if response == 'y'
      fixed_count = 0
      account_users_to_fix.each do |au|
        raw_value = au.role_before_type_cast

        # Mapear valores numéricos para strings de enum
        if raw_value == 1
          au.update_column(:role, "administrator")
          fixed_count += 1
        elsif raw_value == 0
          au.update_column(:role, "agent")
          fixed_count += 1
        end
      end

      # Contar novamente após correção
      admin_count_after = AccountUser.where(role: 1).count
      agent_count_after = AccountUser.where(role: 0).count

      puts "Corrigidos: #{fixed_count} registros"
      puts "Após correção: #{admin_count_after} administradores, #{agent_count_after} agentes"
    else
      puts "Operação cancelada. Nenhum registro foi alterado."
    end
  end

  desc "Lista todos os usuários com seus respectivos papéis em cada conta"
  task list_all_roles: :environment do
    puts "Listando todos os AccountUsers com seus roles..."

    AccountUser.includes(:user, :account).find_each do |au|
      puts "AccountUser ##{au.id} - User: #{au.user&.name} (#{au.user_id}) - Account: #{au.account&.name} (#{au.account_id}) - Role: #{au.role} (#{au.role_before_type_cast})"
    end

    puts "\nContagem por role:"
    AccountUser.group(:role).count.each do |role, count|
      puts "#{role}: #{count}"
    end
  end
end
