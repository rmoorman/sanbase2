defmodule SanbaseWeb.ExAdmin.UserList do
  use ExAdmin.Register

  alias Sanbase.UserList

  register_resource Sanbase.UserList do
    update_changeset(:update_changeset)
    action_items(only: [:show, :edit, :delete])

    scope(:all, default: true)

    scope(:featured, [], fn query ->
      from(
        user_list in query,
        left_join: featured_item in Sanbase.FeaturedItem,
        on: user_list.id == featured_item.user_list_id,
        where: not is_nil(featured_item.id)
      )
      |> distinct(true)
    end)

    scope(:not_featured, [], fn query ->
      from(
        user_list in query,
        left_join: featured_item in Sanbase.FeaturedItem,
        on: user_list.id == featured_item.user_list_id,
        where: is_nil(featured_item.id)
      )
      |> distinct(true)
    end)

    index do
      column(:id)
      column(:name)
      column(:slug)
      column(:type)
      column(:is_featured, &is_featured(&1))
      column(:is_public)
      column(:user)
      column(:function)
    end

    form user_list do
      inputs do
        input(user_list, :name)
        input(user_list, :slug)
        input(user_list, :description)
        input(:type, :watchlist_type)
        input(user_list, :is_public)
        input(user_list, :function, type: :text)

        input(
          user_list,
          :is_featured,
          collection: ~w(true false)
        )
      end
    end

    show user_list do
      attributes_table do
        row(:id)
        row(:name)
        row(:slug)
        row(:description)
        row(:type)
        row(:is_public)
        row(:is_featured, &is_featured(&1))
        row(:color)
        row(:user, link: true)
        row(:function)
        row(:inserted_at)
        row(:updated_at)
      end

      panel "List items" do
        table_for Sanbase.Repo.preload(user_list.list_items, [:project]) do
          column(:project, link: true)
        end
      end
    end

    controller do
      before_filter(:normalize_function, only: [:update])
      after_filter(:set_featured, only: [:update])
    end
  end

  defp is_featured(%UserList{} = ul) do
    ut = Sanbase.Repo.preload(ul, [:featured_item])
    (ut.featured_item != nil) |> Atom.to_string()
  end

  def set_featured(conn, params, resource, :update) do
    is_featured = params.user_list.is_featured |> String.to_existing_atom()
    Sanbase.FeaturedItem.update_item(resource, is_featured)
    {conn, params, resource}
  end

  def normalize_function(conn, params) do
    params =
      put_in(
        params[:user_list][:function],
        Jason.decode!(params.user_list.function)
      )

    params =
      if is_nil(params.user_list.is_featured) do
        is_featured =
          params.id
          |> UserList.by_id()
          |> is_featured

        put_in(params[:user_list][:is_featured], is_featured)
      else
        params
      end

    {conn, params}
  end

  defimpl ExAdmin.Render, for: Sanbase.WatchlistFunction do
    def to_string(data) do
      data |> Map.from_struct() |> Jason.encode!()
    end
  end

  defimpl String.Chars, for: Sanbase.WatchlistFunction do
    def to_string(data) do
      data |> Map.from_struct() |> Jason.encode!()
    end
  end
end
