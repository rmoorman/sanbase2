defmodule SanbaseWeb.Graphql.Resolvers.CommentResolver do
  alias Sanbase.Insight.PostComment
  alias Sanbase.Comment
  alias Sanbase.Comment.EntityComment

  @entities [:insight, :timeline_event]

  # deprecated - should be removed if not used
  def create_comment(
        _root,
        %{insight_id: post_id, content: content} = args,
        %{context: %{auth: %{current_user: user}}}
      ) do
    PostComment.create_and_link(post_id, user.id, Map.get(args, :parent_id), content)
  end

  def create_comment(
        _root,
        %{entity_type: entity_type, id: id, content: content} = args,
        %{context: %{auth: %{current_user: user}}}
      )
      when entity_type in @entities do
    EntityComment.create_and_link(id, user.id, Map.get(args, :parent_id), content, entity_type)
  end

  def create_comment(_root, _args, _resolution), do: {:error, "Invalid args for createComment"}

  @spec update_comment(any, %{comment_id: any, content: any}, %{
          context: %{auth: %{current_user: atom | map}}
        }) :: any
  def update_comment(
        _root,
        %{comment_id: comment_id, content: content},
        %{context: %{auth: %{current_user: user}}}
      ) do
    Comment.update(comment_id, user.id, content)
  end

  def delete_comment(
        _root,
        %{comment_id: comment_id},
        %{context: %{auth: %{current_user: user}}}
      ) do
    Comment.delete(comment_id, user.id)
  end

  def comments(
        _root,
        %{entity_type: entity_type, id: id} = args,
        _resolution
      )
      when entity_type in @entities do
    comments = EntityComment.get_comments(id, args, entity_type) |> Enum.map(& &1.comment)

    {:ok, comments}
  end

  def subcomments(
        _root,
        %{comment_id: comment_id} = args,
        _resolution
      ) do
    {:ok, Comment.get_subcomments(comment_id, args)}
  end
end
