defmodule Snownix.Providers.Github do
  alias SnownixWeb.Router.Helpers, as: Routes

  @scope "user:email"
  @auth_link "https://github.com/login/oauth/"
  @api_link "https://api.github.com/"

  def client_id, do: Snownix.config([:github, :client_id])
  def client_secret, do: Snownix.config([:github, :client_secret])

  def login_callback(conn), do: Routes.github_login_url(conn, :create)
  def register_callback(conn), do: Routes.github_register_url(conn, :create)

  def authorize_link(conn, :login) do
    @auth_link <>
      "authorize?client_id=#{client_id()}&scope=#{@scope}&state=#{state()}&redirect_uri=#{login_callback(conn)}"
  end

  def authorize_link(conn, :register) do
    @auth_link <>
      "authorize?client_id=#{client_id()}&scope=#{@scope}&state=#{state()}&redirect_uri=#{register_callback(conn)}"
  end

  def enabled? do
    !!(client_id() && client_secret())
  end

  def state do
    :crypto.strong_rand_bytes(12)
    |> Base.encode64(padding: false)
  end

  def get_user_resources(code) do
    with {:ok, access_token} <- fetch_access_token(code),
         {:ok, user} <- fetch_user(access_token),
         {:ok, emails} <- fetch_emails(access_token) do
      {:ok,
       user
       |> Map.put("emails", emails)
       |> Map.update!("id", &Kernel.inspect(&1))}
    end
  end

  def fetch_access_token(code) do
    %HTTPoison.Request{
      url: @auth_link <> "access_token",
      headers: [
        Accept: "application/json"
      ],
      method: :post,
      body: access_token_body(code)
    }
    |> HTTPoison.request()
    |> handle_response()
    |> handle_access_token()
  end

  def fetch_user(access_token) do
    %HTTPoison.Request{
      url: @api_link <> "user",
      headers: [
        Accept: "application/json",
        Authorization: "token #{access_token}"
      ],
      method: :get
    }
    |> HTTPoison.request()
    |> handle_response()
  end

  def fetch_emails(access_token) do
    %HTTPoison.Request{
      url: @api_link <> "user/emails",
      headers: [
        Accept: "application/json",
        Authorization: "token #{access_token}"
      ],
      method: :get
    }
    |> HTTPoison.request()
    |> handle_response()
  end

  defp access_token_body(code) do
    {:form,
     [
       client_id: client_id(),
       client_secret: client_secret(),
       code: code
     ]}
  end

  def handle_response({:ok, response = %{status_code: 200}}) do
    {:ok, Jason.decode!(response.body)}
  end

  def handle_response({:ok, response}) do
    {:error, Jason.decode!(response.body)}
  end

  def handle_response({:error, reason}), do: {:error, reason}

  def handle_access_token({:ok, body = %{"error" => _error}}) do
    {:error, body}
  end

  def handle_access_token({:ok, %{"access_token" => access_token}}) do
    {:ok, access_token}
  end

  def handle_access_token({:error, any}) do
    {:error, any}
  end
end
