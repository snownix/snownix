defmodule Snownix.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query
  alias Snownix.Repo
  alias Snownix.Accounts.{User, UserToken, UserNotifier, Identity}

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%Menu{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  ## Database getters

  @doc """
  Gets a user by username.

  ## Examples

      iex> get_user_by_username!("foo@example.com")
      %User{}

      iex> get_user_by_username!("unknown@example.com")
      nil

  """
  def get_user_by_username!(username) when is_binary(username) do
    Repo.get_by!(User, username: username)
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def get_user_by_provider_id(provider, provider_id) do
    query =
      from(u in User,
        inner_join: i in assoc(u, :identities),
        on: i.provider == ^provider and i.provider_id == ^provider_id
      )

    Repo.one(query)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def register_user_from_provider(%Ueberauth.Auth{} = auth) do
    user_id = Kernel.inspect(auth.uid)
    if user = get_user_by_provider_id(auth.provider, user_id) do
      {:ok, user}
    else
      identity = %{provider: auth.provider, provider_id: user_id}

      if user = get_user_by_email(auth.info.email) do
        add_user_identity(user, identity)
      else
        create_provider_user(auth.info, identity)
      end
    end
  end

  def add_user_identity(user, identity) do
    user
    |> Ecto.build_assoc(:identities)
    |> Identity.changeset(identity)
    |> Repo.insert()
    |> case do
      {:ok, _identity} ->
        {:ok, user}

      {:error, _identity} ->
        {:error, user}
    end
  end

  def create_provider_user(%Ueberauth.Auth.Info{} = info, identity) do
    attrs = %{
      identities: [identity],
      email: info.email,
      username: info.nickname,
      fullname: info.name
    }

    %User{}
    |> User.provider_registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        download_and_update_avatar(user, info.image)

      any ->
        any
    end
  end

  defp download_and_update_avatar(user, avatar) do
    avatar_path = download_avatar(avatar)
    update_user_avatar(user, avatar_path)
    File.rm!(avatar_path)
    {:ok, user}
  end

  defp download_avatar(avatar_url) do
    {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get(avatar_url)
    path = "/tmp/#{Ecto.UUID.autogenerate()}.png"
    File.write!(path, body)
    path
  end

  def generate_username(name) do
    username = Slug.slugify(name)

    query =
      from u in User,
        where: u.username == ^username

    if Repo.exists?(query) do
      username <> "#{:rand.uniform(100_000)}"
    else
      username
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> user_register_changeset(user, %{username: ...}, %{hash_password: ...})
      %Ecto.Changeset{data: %User{}}

  """
  def user_register_changeset(%User{} = user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(
      user,
      attrs,
      [hash_password: false] ++ opts
    )
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> user_login_changeset(user)
      %Ecto.Changeset{data: %User{}}

  """
  def user_login_changeset(%User{} = user, attrs \\ %{}) do
    User.login_changeset(user, attrs, hash_password: false)
  end

  ## User Changeset
  @doc """
  Emulates that the user information will change without actually changing
  it in the database.

  ## Examples

      iex> user_changeset(user, %{fullname: ...})
      {:ok, %User{}}

      iex> user_changeset(user, %{fullname: ...})
      {:error, %Ecto.Changeset{}}

  """
  def user_changeset(%User{} = user, attrs \\ %{}) do
    User.user_changeset(user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user avatar.

  The user avatar is updated .
  The old avatar is deleted
  The confirmed_at date is also updated to the current time.
  """
  def update_user_avatar(user, avatar) do
    user
    |> User.avatar_changeset(%{avatar: avatar})
    |> Repo.update()
  end

  @doc """
  Delete the user avatar.

  The update_user_avatar is called with avatar nil value
  """
  def delete_user_avatar(user) do
    update_user_avatar(user, nil)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &Routes.user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> user_password_changeset(user)
      %Ecto.Changeset{data: %User{}}

  """
  def user_password_changeset(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password with email valdiation.

  ## Examples

      iex>  (user)
      %Ecto.Changeset{data: %User{}}

  """
  def user_password_with_email_changeset(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
    |> User.validate_email_changeset(attrs)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Updates the user profile.

  ## Examples

      iex> update_user(user, "valid password", %{fullname: ...})
      {:ok, %User{}}

      iex> update_user(user, "invalid password", %{fullname: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(user, password, attrs) do
    changeset =
      user
      |> User.user_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Gets the user by confirm account token.

  ## Examples

      iex> get_user_by_confirm_account_token("validtoken")
      %User{}

      iex> get_user_by_confirm_account_token("invalidtoken")
      nil

  """
  def get_user_by_confirm_account_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token, email) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query) do
      case user.email == email do
        true ->
          with {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
            {:ok, user}
          end

        false ->
          :error
      end
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &Routes.user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> user_email_changeset(user)
      %Ecto.Changeset{data: %User{}}

  """
  def user_email_changeset(user, attrs \\ %{}) do
    User.validate_email_changeset(user, attrs)
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end
end
