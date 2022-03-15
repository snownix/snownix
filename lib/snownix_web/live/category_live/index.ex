defmodule SnownixWeb.CategoryLive.Index do
  use SnownixWeb, :live_view

  alias Snownix.Posts
  alias Snownix.Posts.Category

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :categories, list_categories())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Category")
    |> assign(:category, Posts.get_category!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Category")
    |> assign(:category, %Category{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Categories")
    |> assign(:category, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    category = Posts.get_category!(id)
    {:ok, _} = Posts.delete_category(category)

    {:noreply, assign(socket, :categories, list_categories())}
  end

  defp list_categories do
    Posts.list_categories()
  end
end
