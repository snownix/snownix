defmodule SnownixWeb.PostLive.Components.FormComponent do
  use SnownixWeb, :live_component

  alias Snownix.Posts

  alias Snownix.Posts

  @impl true
  def update(%{post: post} = assigns, socket) do
    changeset = Posts.change_post(post)

    {:ok,
     socket
     |> assign(draft: false, fullscreen: false, custom_slug: false, changeset: changeset)
     |> assign(assigns)
     |> assign_uploads()
     |> assign_multiselect()}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    %{"query_categories" => query_categories} = post_params

    changeset =
      socket.assigns.post
      |> Posts.change_post(post_params, custom_slug: socket.assigns.custom_slug)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> update_multiselect(:categories, query_categories)}
  end

  def handle_event("custom-slug", _, socket) do
    {:noreply, assign(socket, :custom_slug, true)}
  end

  def handle_event("draft", _, socket) do
    {:noreply, assign(socket, :draft, !socket.assigns.draft)}
  end

  def handle_event("tfullscreen", _, socket) do
    {:noreply, assign(socket, :fullscreen, !socket.assigns.fullscreen)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :images, ref)}
  end

  @doc """
  Append/Drop item to multiselect
  """
  def handle_event("multiselect", %{"list" => list_name, "item" => item, "type" => type}, socket) do
    category = String.to_atom(list_name)

    case type do
      "add" ->
        {:noreply,
         socket
         |> append_item_to_list(category, item)
         |> filter_list_categories()}

      _ ->
        {:noreply,
         socket
         |> drop_item_from_list(category, item)
         |> update_list_categories()}
    end
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.action, post_params)
  end

  defp save_post(socket, :edit, post_params) do
    post = socket.assigns.post
    post_params =
      post_params
      |> Map.put("draft", socket.assigns.draft)
      |> Map.put("categories", socket.assigns.categories)

    case Posts.update_post(post, post_params, custom_slug: socket.assigns.custom_slug) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated successfully")
         |> push_redirect(to: Routes.post_read_path(socket, :read, post.slug))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_post(socket, :new, post_params) do
    author = socket.assigns.current_user
    post =
      post_params
      |> Map.put("draft", socket.assigns.draft)
      |> Map.put("categories", socket.assigns.categories)

    case Posts.create_post(post, author, custom_slug: socket.assigns.custom_slug) do
      {:ok, post} ->
        consume_uploaded_entries(socket, :images, fn meta, entry ->
          {:ok,
           Posts.update_post_poster(post, %Plug.Upload{
             content_type: entry.client_type,
             filename: entry.client_name,
             path: meta.path
           })}
        end)

        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)}
    end
  end

  defp assign_multiselect(socket) do
    socket
    |> assign(:categories, [])
    |> assign(:query_categories, nil)
    |> update_list_categories()
  end

  defp assign_uploads(socket) do
    socket
    |> assign(:uploaded_files, [])
    |> allow_upload(:images, accept: ~w(.jpg .jpeg .png .gif), auto_upload: true, max_entries: 1)
  end

  defp update_list_categories(socket) do
    socket
    |> assign(
      :list_categories,
      []
      # Posts.list_categories(socket.assigns.query_categories)
    )
    |> filter_list_categories()
  end

  defp filter_list_categories(socket) do
    socket
    |> assign(
      :list_categories,
      socket.assigns.list_categories
      |> Enum.reject(fn category ->
        socket.assigns.categories
        |> Enum.find(&(&1.id == category.id))
      end)
    )
  end

  def update_multiselect(socket, :categories, query) do
    socket
    |> assign(:query_categories, query)
    |> update_list_categories()
  end

  defp append_item_to_list(socket, :categories, %{"id" => id, "title" => title}) do
    title = title |> String.trim()

    case Enum.find(socket.assigns.categories, &(&1.id == id || &1.title == title)) do
      nil ->
        category =
          socket.assigns.list_categories
          |> Enum.find(fn c -> c.id == id end)

        socket
        |> assign(
          :categories,
          [
            case is_nil(category) do
              true ->
                case Snownix.Helper.generate_slug(%{title: title}) do
                  %{slug: slug} ->
                    %{id: get_id(), title: title, slug: slug}

                  _ ->
                    nil
                end

              _ ->
                category
            end
            | socket.assigns.categories
          ]
          |> Enum.reject(&is_nil(&1))
        )

      _ ->
        socket
    end
  end

  defp append_item_to_list(socket, :categories, id) when is_binary(id) do
    id = id |> String.trim()

    case socket.assigns.list_categories |> Enum.find(&(&1.id == id || &1.title == id)) do
      %{id: cat_id, title: title} ->
        socket |> append_item_to_list(:categories, %{"id" => cat_id, "title" => title})

      _ ->
        socket
    end
  end

  defp append_item_to_list(socket, _, _), do: socket

  defp drop_item_from_list(socket, :categories, id) when is_binary(id) do
    socket |> assign(:categories, socket.assigns.categories |> Enum.filter(&(&1.id != id)))
  end

  defp drop_item_from_list(socket, _, _), do: socket

  defp get_id, do: Ecto.UUID.generate()
end
