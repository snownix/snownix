defmodule SnownixWeb.PostLive.Read do
  use SnownixWeb, :live_view

  alias Snownix.Posts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    {:noreply,
     socket
     |> assign_post(slug)}
  end

  @impl true
  def handle_event("delete", _, socket) do
    case Posts.delete_post(socket.assigns.current_user, socket.assigns.post) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:success, gettext("Post deleted successfully."))
         |> redirect(to: "/")}

      {:error} ->
        {:noreply, socket |> put_flash(:error, gettext("Only post author can delete this post"))}
    end
  end

  defp assign_post(socket, slug) do
    post = Posts.get_post_by_slug!(slug)

    socket
    |> assign(
      :post,
      post
    )
    |> put_meta_tags(%{
      page_title: gettext("%{title}", title: post.title),
      page_desc: (post.description |> String.slice(0, 160)) <> "...",
      page_author: if(post.author, do: post.author.username, else: nil),
      page_image: get_post_poster(post, :original)
    })
  end
end
