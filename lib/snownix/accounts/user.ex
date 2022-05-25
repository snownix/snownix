defmodule Snownix.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  use Waffle.Ecto.Schema

  alias Snownix.Accounts.Identity

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    field :fullname, :string
    field :avatar, Snownix.Uploaders.AvatarUploader.Type

    field :phone, :string

    field :username, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime

    field :admin, :boolean, default: false

    has_many :identities, Identity, foreign_key: :user_id

    timestamps()
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    uniq_email? = Keyword.get(opts, :uniq_email, true)
    uniq_username? = Keyword.get(opts, :uniq_username, true)

    changeset =
      user
      |> cast(attrs, [:email, :password, :username])
      |> validate_password(opts)

    changeset =
      if uniq_email?,
        do: validate_email(changeset, attrs),
        else: changeset |> validate_email_changeset(attrs)

    if uniq_username?, do: validate_username(changeset), else: changeset
  end

  def provider_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :fullname])
    |> cast_assoc(:identities, with: &Identity.changeset/2, required: true)
    |> validate_required([:email, :username])
    |> validate_email(attrs)
    |> validate_username()
  end

  def login_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email_changeset(attrs)
    |> validate_password(opts)
  end

  def user_changeset(user, attrs) do
    user
    |> cast(attrs, [:fullname, :phone, :username])
    |> validate_length(:fullname, max: 50)
    |> validate_username()
  end

  def avatar_changeset(user, attrs) do
    user
    |> cast_attachments(attrs, [:avatar], allow_paths: true)
  end

  defp validate_email(changeset, attrs) do
    changeset
    |> validate_email_changeset(attrs)
    |> unsafe_validate_unique(:email, Snownix.Repo)
    |> unique_constraint(:email)
  end

  def validate_email_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
  end

  defp validate_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_format(:username, ~r/^[a-zA-Z0-9-_]+$/, message: "username must be alphanumeric")
    |> unsafe_validate_unique(:username, Snownix.Repo)
    |> validate_length(:username, max: 40)
    |> unique_constraint(:username)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email(attrs)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Snownix.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "Wrong password")
    end
  end
end
