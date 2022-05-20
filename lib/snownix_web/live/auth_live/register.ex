defmodule SnownixWeb.AuthLive.Register do
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
      |> Accounts.user_register_changeset(user_params, uniq_email: false)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("create", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.auth_confirm_url(socket, :confirm, &1)
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext(
             "Registration completed successfully. please check your email to verify your account."
           )
         )
         |> redirect(to: Routes.auth_login_path(socket, :login))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)}
    end
  end

  def put_initial_assigns(socket) do
    socket
    |> assign(
      show_form?: false,
      changeset: Accounts.user_register_changeset(%Accounts.User{}),
      page_title: gettext("Sign up")
    )
  end
end
