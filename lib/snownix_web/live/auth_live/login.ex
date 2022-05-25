defmodule SnownixWeb.AuthLive.Login do
  use SnownixWeb, :live_view

  alias Snownix.Accounts

  def mount(_, _, socket) do
    {:ok, put_initial_assigns(socket)}
  end

  def handle_event("show-form", _, socket) do
    {:noreply, assign(socket, :show_form?, true)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %Accounts.User{}
      |> Accounts.user_login_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> clear_flash() |> assign(:changeset, changeset)}
  end

  def handle_event("create", %{"user" => user_params}, socket) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Welcome back %{username}!", username: user.username))
       |> assign(:trigger_submit, true)}
    else
      {:noreply,
       socket
       # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
       |> put_flash(:error, gettext("Invalid email or password"))}
    end
  end

  def put_initial_assigns(socket) do
    socket
    |> assign(
      trigger_submit: false,
      changeset: Accounts.user_login_changeset(%Accounts.User{}),
      page_title: gettext("Sign in"),
      show_form?: false
    )
  end
end
