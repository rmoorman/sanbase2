defmodule Sanbase.Comments.EntityComment do
  @moduledoc """
  Module for dealing with comments for certain entities.
  """
  import Ecto.Query
  import Sanbase.Comments.EventEmitter, only: [emit_event: 3]

  alias Sanbase.Repo
  alias Sanbase.Comment
  alias Sanbase.Timeline.TimelineEventComment
  alias Sanbase.Insight.PostComment
  alias Sanbase.ShortUrl.ShortUrlComment
  alias Sanbase.BlockchainAddress.BlockchainAddressComment
  alias Sanbase.WalletHunters.WalletHuntersProposalComment

  @type entity ::
          :insight | :timeline_event | :short_url | :blockchain_address | :wallet_hunters_proposal

  @spec create_and_link(
          entity,
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer() | nil,
          String.t()
        ) ::
          {:ok, %Comment{}} | {:error, any()}
  def create_and_link(entity, entity_id, user_id, parent_id, content) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(
      :create_comment,
      fn _repo, _changes -> Comment.create(user_id, content, parent_id) end
    )
    |> Ecto.Multi.run(:link_comment_and_entity, fn
      _repo, %{create_comment: comment} ->
        link(entity, entity_id, comment.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{create_comment: comment}} -> {:ok, comment}
      {:error, _name, error, _} -> {:error, error}
    end
    |> emit_event(:create_comment, %{entity: entity})
  end

  @spec link(:insight, non_neg_integer(), non_neg_integer()) ::
          {:ok, %PostComment{}} | {:error, Ecto.Changeset.t()}
  def link(:insight, entity_id, comment_id) do
    %PostComment{}
    |> PostComment.changeset(%{comment_id: comment_id, post_id: entity_id})
    |> Repo.insert()
  end

  @spec link(:timeline_event, non_neg_integer(), non_neg_integer()) ::
          {:ok, %TimelineEventComment{}} | {:error, Ecto.Changeset.t()}
  def link(:timeline_event, entity_id, comment_id) do
    %TimelineEventComment{}
    |> TimelineEventComment.changeset(%{
      comment_id: comment_id,
      timeline_event_id: entity_id
    })
    |> Repo.insert()
  end

  @spec link(:blockchain_address, non_neg_integer(), non_neg_integer()) ::
          {:ok, %BlockchainAddressComment{}} | {:error, Ecto.Changeset.t()}
  def link(:blockchain_address, entity_id, comment_id) do
    %BlockchainAddressComment{}
    |> BlockchainAddressComment.changeset(%{
      comment_id: comment_id,
      blockchain_address_id: entity_id
    })
    |> Repo.insert()
  end

  @spec link(:wallet_hunters_proposal, non_neg_integer(), non_neg_integer()) ::
          {:ok, %WalletHuntersProposalComment{}} | {:error, Ecto.Changeset.t()}
  def link(:wallet_hunters_proposal, entity_id, comment_id) do
    %WalletHuntersProposalComment{}
    |> WalletHuntersProposalComment.changeset(%{
      comment_id: comment_id,
      proposal_id: entity_id
    })
    |> Repo.insert()
  end

  @spec link(:short_url, non_neg_integer(), non_neg_integer()) ::
          {:ok, %ShortUrlComment{}} | {:error, Ecto.Changeset.t()}
  def link(:short_url, entity_id, comment_id) do
    %ShortUrlComment{}
    |> ShortUrlComment.changeset(%{comment_id: comment_id, short_url_id: entity_id})
    |> Repo.insert()
  end

  @spec get_comments(entity, non_neg_integer() | nil, map()) :: [%Comment{}]
  def get_comments(entity, entity_id, %{limit: limit} = args) do
    cursor = Map.get(args, :cursor) || %{}
    order = Map.get(cursor, :order, :asc)

    entity_comments_query(entity, entity_id)
    |> apply_cursor(cursor)
    |> order_by([c], [{^order, c.inserted_at}])
    |> limit(^limit)
    |> Repo.all()
  end

  def get_comments(%{limit: limit} = args) do
    cursor = Map.get(args, :cursor) || %{}
    order = Map.get(cursor, :order, :desc)

    all_comments_query()
    |> apply_cursor(cursor)
    |> order_by([c], [{^order, c.inserted_at}, {^order, c.id}])
    |> limit(^limit)
    |> Repo.all()
    |> transform_entity_list_to_singular()
  end

  # Private Functions

  defp maybe_add_entity_id_clause(query, _field, nil), do: query

  defp maybe_add_entity_id_clause(query, field, entity_id) do
    query
    |> where([elem], field(elem, ^field) == ^entity_id)
  end

  def all_comments_query() do
    from(c in Comment,
      left_join: pc in WalletHuntersProposalComment,
      on: c.id == pc.comment_id,
      where: is_nil(pc.proposal_id),
      preload: [:user, :insights, :timeline_events, :short_urls, :blockchain_addresses]
    )
  end

  # Since polymorphic comments are modeled with many_to_many :through but the actual
  # association is belongs_to, like `comment` belongs_to `insight` we need to
  # transform preloaded entities like so: insights: [%{}] -> insight: %{}
  defp transform_entity_list_to_singular(comments) do
    entities = [:insights, :timeline_events, :short_urls, :blockchain_addresses]

    comments
    |> Enum.map(fn comment ->
      entities
      |> Enum.reduce(comment, fn entity, acc ->
        value = Map.get(acc, entity) |> List.first()
        singular_entity = Inflex.singularize(entity) |> String.to_existing_atom()

        acc
        |> Map.delete(entity)
        |> Map.put(singular_entity, value)
      end)
    end)
  end

  defp entity_comments_query(:timeline_event, entity_id) do
    from(
      comment in TimelineEventComment,
      preload: [:comment, comment: :user]
    )
    |> maybe_add_entity_id_clause(:timeline_event_id, entity_id)
  end

  defp entity_comments_query(:insight, entity_id) do
    from(comment in PostComment,
      preload: [:comment, comment: :user]
    )
    |> maybe_add_entity_id_clause(:post_id, entity_id)
  end

  defp entity_comments_query(:blockchain_address, entity_id) do
    from(comment in BlockchainAddressComment,
      preload: [:comment, comment: :user]
    )
    |> maybe_add_entity_id_clause(:blockchain_address_id, entity_id)
  end

  defp entity_comments_query(:wallet_hunters_proposal, entity_id) do
    from(comment in WalletHuntersProposalComment,
      preload: [:comment, comment: :user]
    )
    |> maybe_add_entity_id_clause(:proposal_id, entity_id)
  end

  defp entity_comments_query(:short_url, entity_id) do
    from(comment in ShortUrlComment,
      preload: [:comment, comment: :user]
    )
    |> maybe_add_entity_id_clause(:short_url_id, entity_id)
  end

  defp apply_cursor(query, %{type: :before, datetime: datetime}) do
    from(c in query, where: c.inserted_at <= ^(datetime |> DateTime.to_naive()))
  end

  defp apply_cursor(query, %{type: :after, datetime: datetime}) do
    from(c in query, where: c.inserted_at >= ^(datetime |> DateTime.to_naive()))
  end

  defp apply_cursor(query, _), do: query
end
