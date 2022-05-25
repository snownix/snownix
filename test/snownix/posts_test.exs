defmodule Snownix.PostsTest do
  use Snownix.DataCase

  alias Snownix.Posts

  describe "posts" do
    alias Snownix.Posts.Post

    import Snownix.PostsFixtures

    @invalid_attrs %{
      description: nil,
      poster: nil,
      published_at: nil,
      slug: nil,
      title: nil,
      read_time: nil
    }

    test "list_posts/0 returns all posts" do
      post = post_fixture()

      posts =
        Posts.list_posts()
        |> Repo.preload([:entities])

      assert posts == [post]
    end

    test "get_post!/1 returns the post with given id" do
      post_created = post_fixture()

      post =
        post_created.id
        |> Posts.get_post!()
        |> Repo.preload([:author, :categories, :entities])

      assert post == post_created
    end

    test "get_post!/1 returns the post with given slug" do
      post = post_fixture()

      assert Posts.get_post_by_slug!(post.slug) == post
    end

    test "create_post/1 with valid data creates a post" do
      valid_attrs = %{
        description: "some description",
        poster: "some poster",
        published_at: ~N[2022-03-05 19:27:00],
        slug: "some-title",
        title: "some title",
        entities: [valide_entity_attrs()]
      }

      assert {:ok, %Post{} = post} = Posts.create_post(valid_attrs)
      assert post.description == "some description"
      assert post.published_at == ~N[2022-03-05 19:27:00]
      assert post.slug == "some-title"
      assert post.title == "some title"
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Posts.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()

      update_attrs = %{
        description: "some updated description",
        poster: "some updated poster",
        published_at: ~N[2022-03-06 19:27:00],
        slug: "some-updated-title",
        title: "some updated title"
      }

      assert {:ok, %Post{} = post} = Posts.update_post(post, update_attrs)
      assert post.description == "some updated description"
      assert post.published_at == ~N[2022-03-06 19:27:00]
      assert post.slug == "some-updated-title"
      assert post.title == "some updated title"
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Posts.update_post(post, @invalid_attrs)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Posts.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Posts.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Posts.change_post(post)
    end
  end

  describe "categories" do
    alias Snownix.Posts.Category

    import Snownix.PostsFixtures

    @invalid_attrs %{description: nil, slug: nil, status: nil, title: nil}

    test "list_categories/0 returns all categories" do
      category = category_fixture()
      assert Posts.list_categories() == [category]
    end

    test "get_category!/1 returns the category with given id" do
      category = category_fixture()
      assert Posts.get_category!(category.id) == category
    end

    test "create_category/1 with valid data creates a category" do
      valid_attrs = %{
        description: "some description",
        slug: "some-title",
        status: "some status",
        title: "some title"
      }

      assert {:ok, %Category{} = category} = Posts.create_category(valid_attrs)
      assert category.description == "some description"
      assert category.slug == "some-title"
      assert category.status == "some status"
      assert category.title == "some title"
    end

    test "create_category/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Posts.create_category(@invalid_attrs)
    end

    test "update_category/2 with valid data updates the category" do
      category = category_fixture()

      update_attrs = %{
        description: "some updated description",
        slug: "some-updated-title",
        status: "some updated status",
        title: "some updated title"
      }

      assert {:ok, %Category{} = category} = Posts.update_category(category, update_attrs)
      assert category.description == "some updated description"
      assert category.slug == "some-updated-title"
      assert category.status == "some updated status"
      assert category.title == "some updated title"
    end

    test "update_category/2 with invalid data returns error changeset" do
      category = category_fixture()
      assert {:error, %Ecto.Changeset{}} = Posts.update_category(category, @invalid_attrs)
      assert category == Posts.get_category!(category.id)
    end

    test "delete_category/1 deletes the category" do
      category = category_fixture()
      assert {:ok, %Category{}} = Posts.delete_category(category)
      assert_raise Ecto.NoResultsError, fn -> Posts.get_category!(category.id) end
    end

    test "change_category/1 returns a category changeset" do
      category = category_fixture()
      assert %Ecto.Changeset{} = Posts.change_category(category)
    end
  end
end
