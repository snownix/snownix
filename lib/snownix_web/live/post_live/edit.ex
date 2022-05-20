defmodule SnownixWeb.PostLive.Edit do
  use SnownixWeb, :live_view

  alias Snownix.Repo
  alias Snownix.Posts

  def render(assigns) do
    ~H"""
      <.live_component
        module={SnownixWeb.PostLive.Components.FormComponent}
        id={@post.id}
        post={@post}
        action={:edit}
        title={@page_title}
        return_to={Routes.index_index_path(@socket, :index)}
      />
    """
  end

  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(
       :post,
       Posts.get_post!(id)
       |> Repo.preload(:categories)
       |> Repo.preload(:entities)
     )}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_metas()
     |> assign(:action, :edit)
     |> assign(:markdown, true)}
  end

  defp assign_metas(socket) do
    socket
    |> assign(:page_title, "Edit Post")
  end
end
