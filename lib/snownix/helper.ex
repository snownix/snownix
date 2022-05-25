defmodule Snownix.Helper do
  @doc """
  Generate a slug and return a tuplet with slug

  ## Examples
      iex> generate_slug(%{ title: "This is an example of title"})
      %{slug: "this-is-an-example-of-title"}

      iex> generate_slug(%{})
      %{}
  """
  def generate_slug(%{title: title}) when not is_nil(title) do
    %{slug: Slug.slugify(title)}
  end

  def generate_slug(%{"title" => title}) when not is_nil(title) do
    %{"slug" => Slug.slugify(title)}
  end

  def generate_slug(_) do
    %{}
  end

  @split_pattern [" ", "\n", "\r", "\t"]
  @words_per_minute 200

  @spec reading_time(String.t(),
          words_per_minute: non_neg_integer(),
          split_pattern: nonempty_list(String.t())
        ) :: number
  @doc """
  Returns the time in minutes for a given string.
  ## Examples
      iex> reading_time("An article content")
      1
      iex> reading_time("An_article_content", words_per_minute: 1, split_pattern: ["_", "-"])
      5
  """
  def reading_time(string, opts \\ []) do
    words_per_minute = Keyword.get(opts, :words_per_minute, @words_per_minute)
    split_pattern = Keyword.get(opts, :split_pattern, @split_pattern)

    words =
      string
      |> String.split(split_pattern, trim: true)
      |> length

    minutes =
      Float.ceil(words / words_per_minute)
      |> trunc

    minutes
  end
end
