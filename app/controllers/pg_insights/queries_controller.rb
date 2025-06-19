# frozen_string_literal: true

module PgInsights
  class QueriesController < PgInsights::ApplicationController
    protect_from_forgery with: :null_session

    before_action :set_query, only: [ :update, :destroy ]

    # POST /pg_insights/queries
    def create
      @query = PgInsights::Query.new(query_params)
      if @query.save
        render json: { success: true, query: @query.as_json(only: [ :id, :name, :sql, :description ]) }, status: :created
      else
        render json: { success: false, errors: @query.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /pg_insights/queries/:id
    def update
      if @query.update(query_params)
        render json: { success: true, query: @query.as_json(only: [ :id, :name, :sql, :description ]) }
      else
        render json: { success: false, errors: @query.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /pg_insights/queries/:id
    def destroy
      @query.destroy
      head :no_content
    end

    private

    def set_query
      @query = PgInsights::Query.find(params[:id])
    end

    def query_params
      params.require(:query).permit(:name, :sql, :description, :category)
    end
  end
end
