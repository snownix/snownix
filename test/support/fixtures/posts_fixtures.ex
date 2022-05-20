defmodule Snownix.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Snownix.Posts` context.
  """
  alias Snownix.AccountsFixtures


  @category %{
    description: "some description",
    slug: "some-title",
    status: "some status",
    title: "some title"
  }

  def valide_entity_attrs do
    %{
      body:
        "We did a lot in this tutorial: learned about native web components, native Javascript" <>
          " module import, CSS import and the shadow DOM. We were careful to create a responsive" <>
          " UI and give it sensible features. Today we are at the end of this series, with one last" <>
          " thing remaining: creating the Rust API that would load and serve RSS content.",
      order: 0,
      type: "text"
    }
  end

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{
        description: "some description",
        poster: "some poster",
        published_at: ~N[2022-03-05 19:27:00],
        slug: "some-title",
        title: "some title",
        read_time: 0,
        entities: [valide_entity_attrs()],
        categories: [@category]
      })
      |> Snownix.Posts.create_post(AccountsFixtures.user_fixture())

    post
  end

  @doc """
  Generate a category.
  """
  def category_fixture(attrs \\ %{}) do
    {:ok, category} =
      attrs
      |> Enum.into(@category)
      |> Snownix.Posts.create_category()

    category
  end
end
