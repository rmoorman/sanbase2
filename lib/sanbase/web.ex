defmodule Sanbase.Application.Web do
  import Sanbase.ApplicationUtils
  require Logger

  def init() do
    # API metrics
    SanbaseWeb.Graphql.Prometheus.HistogramInstrumenter.install(SanbaseWeb.Graphql.Schema)
    SanbaseWeb.Graphql.Prometheus.CounterInstrumenter.install(SanbaseWeb.Graphql.Schema)
  end

  @doc ~s"""
  Return the children and options that will be started in the web container.
  Along with these children all children from `Sanbase.Application.common_children/0`
  will be started, too.
  """
  def children() do
    # Define workers and child supervisors to be supervised
    children = [
      {Absinthe.Subscription, SanbaseWeb.Endpoint},

      # Start the graphQL in-memory cache
      SanbaseWeb.Graphql.Cache.child_spec(
        id: :graphql_api_cache,
        name: :graphql_cache
      ),

      # Time sereies Twitter DB connection
      Sanbase.Twitter.Store.child_spec(),

      # Sweeping the Guardian JWT refresh tokens
      {Guardian.DB.Token.SweeperServer, []},
      # Rehydrating cache
      Sanbase.Cache.RehydratingCache.Supervisor,

      # Transform a list of transactions into a list of transactions
      # where addresses are marked whether or not they are an exchange address
      Sanbase.Clickhouse.MarkExchanges,

      # Start libcluster
      start_in(
        {Cluster.Supervisor,
         [
           Application.get_env(:libcluster, :topologies),
           [name: Sanbase.ClusterSupervisor]
         ]},
        [:prod]
      )
    ]

    opts = [
      name: Sanbase.WebSupervisor,
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 1
    ]

    {children, opts}
  end
end
