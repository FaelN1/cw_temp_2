class FixAccountUserRoles < ActiveRecord::Migration[7.0]
  def up
    # Verificar o model para a definição correta de enum
    # Imprime no console para debug
    puts "Verificando o modelo AccountUser..."
    puts "Roles definidos: #{AccountUser.roles.inspect}"

    # Contar roles atuais para diagnóstico
    admin_count_before = AccountUser.where(role: 1).count
    agent_count_before = AccountUser.where(role: 0).count
    puts "Antes da correção: #{admin_count_before} administradores, #{agent_count_before} agentes"

    # Importante: Utilizando role_before_type_cast para acessar o valor bruto numérico
    account_users_to_fix = AccountUser.all.select do |au|
      (au.role_before_type_cast == 1 && !au.administrator?) ||
      (au.role_before_type_cast == 0 && !au.agent?)
    end

    puts "Encontrados #{account_users_to_fix.count} registros com inconsistências de role"

    # Atualiza os registros problema um por um para garantir que triggers e callbacks funcionem corretamente
    fixed_count = 0
    account_users_to_fix.each do |au|
      raw_value = au.role_before_type_cast

      # Define explicitamente o valor usando a string do enum
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
  end

  def down
    # Esta é uma migração de correção de dados, não precisa de rollback específico
    puts "Esta é uma migração de correção de dados, nenhum rollback necessário"
  end
end
