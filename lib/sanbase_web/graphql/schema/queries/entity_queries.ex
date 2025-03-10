defmodule SanbaseWeb.Graphql.Schema.EntityQueries do
  @moduledoc ~s"""
  Queries and mutations for working with Insights
  """
  use Absinthe.Schema.Notation

  import SanbaseWeb.Graphql.Cache, only: [cache_resolve: 2]

  alias SanbaseWeb.Graphql.Resolvers.EntityResolver

  object :entity_queries do
    field :get_most_voted, list_of(:entity_result) do
      meta(access: :free)
      arg(:type, :entity_type)
      arg(:page, :integer)
      arg(:page_size, :integer)

      cache_resolve(&EntityResolver.get_most_voted/3, ttl: 30, max_ttl_offset: 30)
    end

    field :get_most_recent, list_of(:entity_result) do
      meta(access: :free)
      arg(:type, :entity_type)
      arg(:page, :integer)
      arg(:page_size, :integer)

      resolve(&EntityResolver.get_most_recent/3)
    end
  end

  object :entity_mutations do
  end
end
