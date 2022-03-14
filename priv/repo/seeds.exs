# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Snownix.Repo.insert!(%Snownix.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

defmodule Snownix.Seeds do
  import Ecto.Query, only: [from: 2]
  import Snownix.Helper

  alias Snownix.Repo
  alias Snownix.Posts.Post
  alias Snownix.Posts.Entity
  alias Snownix.Accounts.User
  alias Snownix.Navigation.Menu

  def import_demo() do
    insert_demo_users()
    insert_demo_posts()
  end

  def import_start_menus() do
    Repo.insert_all(Menu, [
      %{
        title: "Home",
        link: "/",
        newtab: false,
        status: "active",
        inserted_at: get_naive_datetime(),
        updated_at: get_naive_datetime(1_000_000)
      },
      %{
        title: "Blog",
        link: "/posts",
        newtab: false,
        status: "active",
        inserted_at: get_naive_datetime(),
        updated_at: get_naive_datetime(1_000_000)
      },
      %{
        title: "Projects",
        link: "/pages/projects",
        newtab: false,
        status: "active",
        inserted_at: get_naive_datetime(),
        updated_at: get_naive_datetime(1_000_000)
      },
      %{
        title: "About",
        link: "/pages/about",
        newtab: false,
        status: "active",
        inserted_at: get_naive_datetime(),
        updated_at: get_naive_datetime(1_000_000)
      },
      %{
        title: "Github",
        link: "https://github.com/snownix",
        newtab: true,
        status: "active",
        inserted_at: get_naive_datetime(),
        updated_at: get_naive_datetime(1_000_000)
      }
    ])
  end

  def insert_demo_users() do
    Repo.insert_all(User, [
      %{
        username: "jone",
        fullname: "Jone Doe",
        phone: "+212612345678",
        email: "jone@snownix.io",
        hashed_password: "jonepassword",
        confirmed_at: get_naive_datetime(),
        inserted_at: get_naive_datetime(),
        updated_at: get_naive_datetime(1_000_000),
        admin: true
      }
    ])
  end

  @doc """
  Insert random lorem posts
  """
  def insert_demo_posts() do
    posts =
      Enum.to_list(1..30)
      |> Enum.map(fn index ->
        title = Faker.Lorem.paragraph(1..2)
        description = Faker.Lorem.paragraphs(1..2) |> Enum.join("\n")

        Map.merge(Snownix.Helper.generate_slug(%{title: title}), %{
          title: title,
          description: description,
          poster:
            "https://source.unsplash.com/random/800x400?" <> String.duplicate("computer,", index),
          inserted_at: get_naive_datetime(),
          published_at: get_naive_datetime(1_000_000),
          updated_at: get_naive_datetime(5_000_000),
          read_time: reading_time(description),
          author_id: select_random_user_id()
        })
      end)

    {_, items} = Repo.insert_all(Post, posts, returning: [:id])

    items
    |> Enum.map(fn post ->
      generate_random_entities(post)
    end)
  end

  defp generate_random_entities(post) do
    read_time = if is_integer(post.read_time), do: post.read_time, else: 0

    read_time =
      Enum.reduce(Enum.to_list(1..5), read_time, fn order, total ->
        body = Faker.Lorem.paragraphs(2..3) |> Enum.join("\n")

        Repo.insert(%Entity{
          post_id: post.id,
          body: body,
          type: "text",
          order: order
        })

        total + reading_time(body)
      end)

    Ecto.Changeset.change(post, read_time: read_time)
    |> Repo.update!()
  end

  defp select_random_user_id() do
    query =
      from t in User,
        order_by: fragment("RANDOM()"),
        limit: 1

    case Repo.all(query) |> List.first() do
      user -> user.id
      _ -> nil
    end
  end

  defp get_naive_datetime() do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

  defp get_naive_datetime(time_to_add) do
    get_naive_datetime() |> NaiveDateTime.add(time_to_add)
  end
end

# dev/test branch
if Application.get_env(:snownix, :environment) != :prod do
  Snownix.Seeds.import_demo()
end

Snownix.Seeds.import_start_menus()
