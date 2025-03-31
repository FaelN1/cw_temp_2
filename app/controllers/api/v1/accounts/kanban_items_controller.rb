class Api::V1::Accounts::KanbanItemsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_item, except: [:index, :create]

  def index
    authorize KanbanItem
    funnel_id = params[:funnel_id]
    
    # Impedir cache do navegador
    response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = 'Fri, 01 Jan 1990 00:00:00 GMT'
    
    @kanban_items = Current.account.kanban_items
                          .for_funnel(funnel_id)
                          .order_by_position

    Rails.logger.debug("KanbanItems encontrados: #{@kanban_items.size}")
    
    # Serializar usando to_json explícito com conversões literais
    result = []
    
    @kanban_items.each do |item|
      Rails.logger.debug("Processando item ID: #{item.id}, display_id: #{item.conversation_display_id}")
      
      item_hash = {
        id: item.id,
        funnel_id: item.funnel_id,
        funnel_stage: item.funnel_stage,
        position: item.position,
        conversation_display_id: item.conversation_display_id,
        timer_started_at: item.timer_started_at,
        timer_duration: item.timer_duration,
        custom_attributes: item.custom_attributes,
        item_details: item.item_details.dup || {}
      }
      
      # Garantir que item_details seja um hash
      item_hash[:item_details] = {} unless item_hash[:item_details].is_a?(Hash)
      
      # Buscar conversa diretamente pelo conversation_display_id
      if item.conversation_display_id.present?
        Rails.logger.debug("Buscando conversa com display_id: #{item.conversation_display_id}")
        
        conversation = Current.account.conversations.find_by(display_id: item.conversation_display_id)
        
        if conversation
          Rails.logger.debug("Conversa encontrada: #{conversation.id}")
          
          # Atualizar o campo conversation_id no item_details, caso não exista
          item_hash[:item_details]['conversation_id'] = conversation.id unless item_hash[:item_details]['conversation_id'].present?
          
          # Criar a estrutura conversation explicitamente
          item_hash[:item_details]['conversation'] = {
            id: conversation.id,
            display_id: conversation.display_id,
            inbox_id: conversation.inbox_id,
            account_id: conversation.account_id,
            status: conversation.status,
            priority: conversation.priority,
            team_id: conversation.team_id,
            campaign_id: conversation.campaign_id,
            snoozed_until: conversation.snoozed_until,
            waiting_since: conversation.waiting_since,
            first_reply_created_at: conversation.first_reply_created_at,
            last_activity_at: conversation.last_activity_at,
            additional_attributes: conversation.additional_attributes,
            custom_attributes: conversation.custom_attributes,
            uuid: conversation.uuid,
            created_at: conversation.created_at,
            updated_at: conversation.updated_at,
            label_list: conversation.cached_label_list_array,
            unread_count: conversation.unread_messages.count,
            assignee: conversation.assignee.present? ? {
              id: conversation.assignee.id,
              name: conversation.assignee.name,
              email: conversation.assignee.email,
              avatar_url: conversation.assignee.avatar_url,
              availability_status: conversation.assignee.availability_status
            } : nil,
            contact: conversation.contact.present? ? {
              id: conversation.contact.id,
              name: conversation.contact.name,
              email: conversation.contact.email,
              phone_number: conversation.contact.phone_number,
              thumbnail: conversation.contact.avatar_url,
              additional_attributes: conversation.contact.additional_attributes
            } : nil,
            messages_count: conversation.messages.count,
            inbox: {
              id: conversation.inbox.id,
              name: conversation.inbox.name,
              channel_type: conversation.inbox.channel_type
            }
          }
        else
          Rails.logger.debug("Conversa não encontrada para display_id: #{item.conversation_display_id}")
        end
      elsif item.item_details['conversation_id'].present?
        # Fallback para buscar pelo conversation_id em item_details
        conversation_id = item.item_details['conversation_id']
        Rails.logger.debug("Fallback: Buscando conversa com ID: #{conversation_id}")
        
        conversation = Current.account.conversations.find_by(id: conversation_id)
        
        if conversation
          Rails.logger.debug("Conversa encontrada via fallback: #{conversation.id}")
          # Criar a estrutura conversation explicitamente
          item_hash[:item_details]['conversation'] = {
            id: conversation.id,
            display_id: conversation.display_id,
            inbox_id: conversation.inbox_id,
            account_id: conversation.account_id,
            status: conversation.status,
            priority: conversation.priority,
            team_id: conversation.team_id,
            campaign_id: conversation.campaign_id,
            snoozed_until: conversation.snoozed_until,
            waiting_since: conversation.waiting_since,
            first_reply_created_at: conversation.first_reply_created_at,
            last_activity_at: conversation.last_activity_at,
            additional_attributes: conversation.additional_attributes,
            custom_attributes: conversation.custom_attributes,
            uuid: conversation.uuid,
            created_at: conversation.created_at,
            updated_at: conversation.updated_at,
            label_list: conversation.cached_label_list_array,
            unread_count: conversation.unread_messages.count,
            assignee: conversation.assignee.present? ? {
              id: conversation.assignee.id,
              name: conversation.assignee.name,
              email: conversation.assignee.email,
              avatar_url: conversation.assignee.avatar_url,
              availability_status: conversation.assignee.availability_status
            } : nil,
            contact: conversation.contact.present? ? {
              id: conversation.contact.id,
              name: conversation.contact.name,
              email: conversation.contact.email,
              phone_number: conversation.contact.phone_number,
              thumbnail: conversation.contact.avatar_url,
              additional_attributes: conversation.contact.additional_attributes
            } : nil,
            messages_count: conversation.messages.count,
            inbox: {
              id: conversation.inbox.id,
              name: conversation.inbox.name,
              channel_type: conversation.inbox.channel_type
            }
          }
        else
          Rails.logger.debug("Conversa não encontrada para o ID: #{conversation_id}")
        end
      end
      
      # Carregar dados do agente atribuído
      if item.item_details['agent_id'].present?
        agent_id = item.item_details['agent_id']
        Rails.logger.debug("Buscando agente com ID: #{agent_id}")
        agent = User.find_by(id: agent_id)
        
        if agent
          Rails.logger.debug("Agente encontrado: #{agent.id}")
          item_hash[:item_details]['agent'] = {
            id: agent.id,
            name: agent.name,
            email: agent.email,
            avatar_url: agent.avatar_url,
            availability_status: agent.availability_status
          }
        else
          Rails.logger.debug("Agente não encontrado para o ID: #{agent_id}")
        end
      end
      
      result << item_hash
    end
    
    render json: result.to_json
  end

  def show
    authorize @kanban_item
    
    item_hash = @kanban_item.as_json

    # Garantir que item_details seja um hash
    item_hash["item_details"] = item_hash["item_details"].presence || {}
    
    # Buscar dados da conversa associada
    if @kanban_item.conversation_display_id.present?
      conversation = Current.account.conversations.find_by(display_id: @kanban_item.conversation_display_id)
      
      if conversation
        # Atualizar o campo conversation_id no item_details, caso não exista
        item_hash["item_details"]["conversation_id"] = conversation.id unless item_hash["item_details"]["conversation_id"].present?
        
        # Criar a estrutura conversation explicitamente
        item_hash["item_details"]["conversation"] = {
          id: conversation.id,
          display_id: conversation.display_id,
          inbox_id: conversation.inbox_id,
          account_id: conversation.account_id,
          status: conversation.status,
          priority: conversation.priority,
          team_id: conversation.team_id,
          campaign_id: conversation.campaign_id,
          snoozed_until: conversation.snoozed_until,
          waiting_since: conversation.waiting_since,
          first_reply_created_at: conversation.first_reply_created_at,
          last_activity_at: conversation.last_activity_at,
          additional_attributes: conversation.additional_attributes,
          custom_attributes: conversation.custom_attributes,
          uuid: conversation.uuid,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at,
          label_list: conversation.cached_label_list_array,
          unread_count: conversation.unread_messages.count,
          assignee: conversation.assignee.present? ? {
            id: conversation.assignee.id,
            name: conversation.assignee.name,
            email: conversation.assignee.email,
            avatar_url: conversation.assignee.avatar_url,
            availability_status: conversation.assignee.availability_status
          } : nil,
          contact: conversation.contact.present? ? {
            id: conversation.contact.id,
            name: conversation.contact.name,
            email: conversation.contact.email,
            phone_number: conversation.contact.phone_number,
            thumbnail: conversation.contact.avatar_url,
            additional_attributes: conversation.contact.additional_attributes
          } : nil,
          messages_count: conversation.messages.count,
          inbox: {
            id: conversation.inbox.id,
            name: conversation.inbox.name,
            channel_type: conversation.inbox.channel_type
          }
        }
      end
    elsif @kanban_item.item_details["conversation_id"].present?
      # Fallback para buscar pelo conversation_id em item_details
      conversation_id = @kanban_item.item_details["conversation_id"]
      
      conversation = Current.account.conversations.find_by(id: conversation_id)
      
      if conversation
        # Criar a estrutura conversation explicitamente
        item_hash["item_details"]["conversation"] = {
          id: conversation.id,
          display_id: conversation.display_id,
          inbox_id: conversation.inbox_id,
          account_id: conversation.account_id,
          status: conversation.status,
          priority: conversation.priority,
          team_id: conversation.team_id,
          campaign_id: conversation.campaign_id,
          snoozed_until: conversation.snoozed_until,
          waiting_since: conversation.waiting_since,
          first_reply_created_at: conversation.first_reply_created_at,
          last_activity_at: conversation.last_activity_at,
          additional_attributes: conversation.additional_attributes,
          custom_attributes: conversation.custom_attributes,
          uuid: conversation.uuid,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at,
          label_list: conversation.cached_label_list_array,
          unread_count: conversation.unread_messages.count,
          assignee: conversation.assignee.present? ? {
            id: conversation.assignee.id,
            name: conversation.assignee.name,
            email: conversation.assignee.email,
            avatar_url: conversation.assignee.avatar_url,
            availability_status: conversation.assignee.availability_status
          } : nil,
          contact: conversation.contact.present? ? {
            id: conversation.contact.id,
            name: conversation.contact.name,
            email: conversation.contact.email,
            phone_number: conversation.contact.phone_number,
            thumbnail: conversation.contact.avatar_url,
            additional_attributes: conversation.contact.additional_attributes
          } : nil,
          messages_count: conversation.messages.count,
          inbox: {
            id: conversation.inbox.id,
            name: conversation.inbox.name,
            channel_type: conversation.inbox.channel_type
          }
        }
      end
    end
    
    # Carregar dados do agente atribuído
    if @kanban_item.item_details["agent_id"].present?
      agent_id = @kanban_item.item_details["agent_id"]
      agent = User.find_by(id: agent_id)
      
      if agent
        item_hash["item_details"]["agent"] = {
          id: agent.id,
          name: agent.name,
          email: agent.email,
          avatar_url: agent.avatar_url,
          availability_status: agent.availability_status
        }
      end
    end
    
    render json: item_hash
  end

  def create
    @kanban_item = Current.account.kanban_items.new(kanban_item_params)
    
    # Se houver um conversation_id nos item_details, define o conversation_display_id
    if @kanban_item.item_details['conversation_id'].present?
      @kanban_item.conversation_display_id = @kanban_item.item_details['conversation_id']
    end

    authorize @kanban_item
    
    if @kanban_item.save
      render json: @kanban_item
    else
      render json: { errors: @kanban_item.errors }, status: :unprocessable_entity
    end
  end

  def update
    authorize @kanban_item
    
    # Se houver um conversation_id nos item_details, define o conversation_display_id
    if kanban_item_params.dig(:item_details, 'conversation_id').present?
      params[:kanban_item][:conversation_display_id] = kanban_item_params.dig(:item_details, 'conversation_id')
    end

    if @kanban_item.update(kanban_item_params)
      render json: @kanban_item
    else
      render json: { errors: @kanban_item.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @kanban_item
    @kanban_item.destroy!
    head :ok
  end

  def move_to_stage
    authorize @kanban_item, :move_to_stage?
    @kanban_item.move_to_stage(params[:funnel_stage])
    head :ok
  end

  def reorder
    authorize KanbanItem, :reorder?
    
    ActiveRecord::Base.transaction do
      params[:positions].each do |position|
        item = Current.account.kanban_items.find(position[:id])
        item.update!(
          position: position[:position],
          funnel_stage: position[:funnel_stage]
        )
      end
    end
    
    head :ok
  end

  def debug
    authorize KanbanItem
    funnel_id = params[:funnel_id]
    
    kanban_items = Current.account.kanban_items
                          .for_funnel(funnel_id)
                          .order_by_position
    
    debug_info = {
      environment: Rails.env,
      ruby_version: RUBY_VERSION,
      rails_version: Rails::VERSION::STRING,
      kanban_items_count: kanban_items.size,
      first_item_sample: kanban_items.first&.as_json,
      has_conversation_data: kanban_items.any? { |item| item.item_details['conversation_id'].present? }
    }
    
    render json: debug_info
  end

  private

  def fetch_kanban_item
    @kanban_item = Current.account.kanban_items.find(params[:id])
  end

  def kanban_item_params
    params.require(:kanban_item).permit(
      :funnel_id,
      :funnel_stage,
      :position,
      :conversation_display_id,
      :timer_started_at,
      :timer_duration,
      custom_attributes: {},
      item_details: {}
    )
  end
end 