defmodule Sanbase.Model.Project.SocialVolumeQuery.CronJob do
  alias Sanbase.Model.Project
  alias Sanbase.Model.Project.SocialVolumeQuery

  def run() do
    project_id_to_autogen_query_map = project_id_to_autogen_query_map()
    project_id_to_query_struct_map = project_id_to_query_struct_map()

    Enum.map(project_id_to_autogen_query_map, fn {project_id, autogen_query} ->
      case Map.get(project_id_to_query_struct_map, project_id) do
        %SocialVolumeQuery{autogenerated_query: ^autogen_query} ->
          nil

        %SocialVolumeQuery{} = struct ->
          SocialVolumeQuery.changeset(struct, %{autogenerated_query: autogen_query})

        _ ->
          SocialVolumeQuery.changeset(
            %SocialVolumeQuery{},
            %{
              project_id: project_id,
              autogenerated_query: autogen_query
            }
          )
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> insert_all()
  end

  defp insert_all(changesets) do
    changesets
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {changeset, offset}, multi ->
      multi
      |> Ecto.Multi.insert(offset, changeset,
        conflict_target: [:project_id],
        on_conflict: :replace_all
      )
    end)
    |> Sanbase.Repo.transaction()
    |> case do
      {:ok, _} -> :ok
      {:error, _name, error, _changes_so_far} -> {:error, error}
    end
  end

  defp project_id_to_query_struct_map() do
    Sanbase.Repo.all(SocialVolumeQuery)
    |> Sanbase.Repo.preload([:project])
    |> Map.new(fn %SocialVolumeQuery{} = svq -> {svq.project_id, svq} end)
  end

  defp project_id_to_autogen_query_map() do
    all_projects = Project.List.projects(preload: [:social_volume_query], include_hidden: true)

    Map.new(
      all_projects,
      fn
        %Project{} = project ->
          default_query_parts = SocialVolumeQuery.default_query_parts(project)

          exclusion_string =
            all_projects
            |> filter_similar_projects(project)
            |> Enum.map(&String.downcase(&1.name))
            |> Enum.reject(&(&1 in default_query_parts))
            |> Enum.uniq()
            |> Enum.map(fn excluded_project_name -> "NOT \"#{excluded_project_name}\"" end)
            |> Enum.join(" ")

          query = SocialVolumeQuery.default_query(project)

          {project.id, String.trim(query <> " " <> exclusion_string)}
      end
    )
  end

  defp filter_similar_projects(all_projects, %Project{slug: project_slug} = project) do
    default_query_parts = SocialVolumeQuery.default_query_parts(project)

    Enum.filter(all_projects, fn
      %Project{slug: ^project_slug} ->
        false

      %Project{name: other_name} ->
        name_tokens = String.downcase(other_name) |> String.split([" ", "-"])
        Enum.any?(name_tokens, &(&1 in default_query_parts))
    end)
  end
end
