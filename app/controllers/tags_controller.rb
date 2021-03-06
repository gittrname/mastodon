# frozen_string_literal: true

class TagsController < ApplicationController
  PAGE_SIZE = 20

  before_action :set_body_classes
  before_action :set_instance_presenter

  def show
    @tag = Tag.find_by!(name: params[:id].downcase)

    respond_to do |format|
      format.html do
        serializable_resource = ActiveModelSerializers::SerializableResource.new(InitialStatePresenter.new(initial_state_params), serializer: InitialStateSerializer)
        @initial_state_json   = serializable_resource.to_json
      end

      format.rss do
        @statuses = HashtagQueryService.new.call(@tag, params.slice(:any, :all, :none)).limit(PAGE_SIZE)
        @statuses = cache_collection(@statuses, Status)

        render xml: RSS::TagSerializer.render(@tag, @statuses)
      end

      format.json do
        @statuses = HashtagQueryService.new.call(@tag, params.slice(:any, :all, :none), current_account, params[:local])
                                       .paginate_by_max_id(PAGE_SIZE, params[:max_id])
        @statuses = cache_collection(@statuses, Status)

        render json: collection_presenter,
               serializer: ActivityPub::CollectionSerializer,
               adapter: ActivityPub::Adapter,
               content_type: 'application/activity+json'
      end
    end
  end

  private

  def set_body_classes
    @body_classes = 'with-modals'
  end

  def set_instance_presenter
    @instance_presenter = InstancePresenter.new
  end

  def collection_presenter
    ActivityPub::CollectionPresenter.new(
      id: tag_url(@tag, params.slice(:any, :all, :none)),
      type: :ordered,
      size: @tag.statuses.count,
      items: @statuses.map { |s| ActivityPub::TagManager.instance.uri_for(s) }
    )
  end

  def initial_state_params
    {
      settings: {},
      token: current_session&.token,
    }
  end
end
