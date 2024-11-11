defmodule Turnstile do
  @behaviour Turnstile.Behaviour
  @moduledoc """
  Use Cloudflare Turnstile in Phoenix. Check out the [README](readme.html) to get started.
  """

  import Phoenix.Component

  alias Phoenix.LiveView

  @script_url "https://challenges.cloudflare.com/turnstile/v0/api.js"
  @verify_url "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  @impl true
  @doc """
  Returns the configured site key.
  """
  def site_key, do: Application.get_env(:phoenix_turnstile, :site_key, "1x00000000000000000000AA")

  @impl true
  @doc """
  Returns the configured secret key.
  """
  def secret_key, do: Application.get_env(:phoenix_turnstile, :secret_key, "1x0000000000000000000000000000000AA")

  @doc """
  Renders the Turnstile script tag.

  Uses explicit rendering so it works with hooks. Additional attributes will be passed through to
  the script tag.
  """
  def script(assigns) do
    assigns =
      assigns
      |> assign(:url, @script_url)
      |> assign(:rest, assigns_to_attributes(assigns, [:noHook]))

    ~H"""
    <script defer src={"#{@url}?render=explicit"} {@rest} />
    """
  end

  @doc """
  Renders the Turnstile widget.

  ## Attributes

    * `:id` - The ID of the element. Defaults to `"cf-turnstile"`.
    * `:class` - The class name passed to the element. Defaults to `nil`.
    * `:hook` - The phx-hook used. Defaults to `"Turnstile"`.
    * `:sitekey` - The Turnstile site key. Defaults to the `:site_key` config value.
    * `:events` - An atom list of the callback events to listen for for in the Live View. See [events](readme.html#events).

  All other attributes will be passed through to the element as `data-*` attributes so the widget
  can be customized. See the [Turnstile docs](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configurations)
  for a list of available attributes.
  """
  def widget(assigns) do
    rest =
      assigns
      |> assigns_to_attributes([:id, :class, :hook, :sitekey, :events])
      |> Enum.map(fn {k, v} -> {"data-#{k}", v} end)
      |> Keyword.put(:class, assigns[:class])

    events =
      assigns
      |> Map.get(:events, [])
      |> Enum.join(",")
      |> case do
        "" -> nil
        value -> value
      end

    assigns =
      assigns
      |> assign_new(:id, fn -> "cf-turnstile" end)
      |> assign_new(:hook, fn -> "Turnstile" end)
      |> assign_new(:sitekey, &site_key/0)
      |> assign(:events, events)
      |> assign(:rest, rest)

    ~H"""
    <div
      id={@id}
      phx-hook={@hook}
      phx-update="ignore"
      data-sitekey={@sitekey}
      data-events={@events}
      {@rest}
    />
    """
  end

  @impl true
  @doc """
  Refreshes the Turnstile widget in a LiveView.

  Since the widget uses `phx-update="ignore"`, this function can be used if the widget needs to be
  re-mounted in the DOM, such as when the verification fails. If there are multiple Turnstile
  widgets on the page and you only want to refresh one of them, pass a DOM ID as the second
  argument. Otherwise they will all be refreshed.
  """
  def refresh(%LiveView.Socket{} = socket, id \\ nil) do
    LiveView.push_event(socket, "turnstile:refresh", %{id: id})
  end

  @impl true
  @doc """
  Removes the Turnstile widget from a LiveView.

  Since the widget uses `phx-update="ignore"`, this function can be used if the widget needs to be
  removed from the DOM. If there are multiple Turnstile widgets on the page and you only want to
  refresh one of them, pass a DOM ID as the second argument. Otherwise they will all be removed.
  """
  def remove(%LiveView.Socket{} = socket, id \\ nil) do
    LiveView.push_event(socket, "turnstile:remove", %{id: id})
  end

  @impl true
  @doc """
  Calls the Turnstile verify endpoint with a response token.

  Expects a map with string keys that contains a value for `"cf-response-token"` (see
  [verification](readme.html#verification) for more info). The remote IP can be passed for extra
  security when running the verification, but is optional. Returns `{:ok, response}` if the
  verification succeeded, or `{:error, reason}` if the verification failed.
  """
  def verify(params, opts \\ [])

  def verify(%{"cf-turnstile-response" => turnstile_response}, opts) when is_list(opts) do
    body =
      if Keyword.keyword?(opts) do
        remote_ip = Keyword.get(opts, :remote_ip)
        idempotency_key = Keyword.get(opts, :idempotency_key)
        encode_body!(turnstile_response, remote_ip, idempotency_key)
      else
        encode_body!(turnstile_response, to_string(opts))
      end

    headers = [{to_charlist("accept"), to_charlist("application/json")}]
    request = {to_charlist(@verify_url), headers, to_charlist("application/json"), body}

    case :httpc.request(:post, request, [ssl: ssl_opts()], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        body = Jason.decode!(body)

        if body["success"] do
          {:ok, body}
        else
          {:error, body}
        end

      {:ok, {_, _, body}} ->
        {:error, body}

      {:error, error} ->
        {:error, error}
    end
  end

  def verify(%{"cf-turnstile-response" => _} = params, remoteip) do
    verify(params, remote_ip: remoteip)
  end

  defp encode_body!(response, remoteip, idempotency_key \\ nil)

  defp encode_body!(response, remoteip, idempotency_key) when is_tuple(remoteip) do
    encode_body!(response, :inet_parse.ntoa(remoteip) |> to_string(), idempotency_key)
  end

  defp encode_body!(response, remoteip, idempotency_key) when is_list(remoteip) do
    encode_body!(response, to_string(remoteip), idempotency_key)
  end

  defp encode_body!(response, remoteip, idempotency_key) do
    %{response: response, remoteip: remoteip, secret: secret_key(), idempotency_key: idempotency_key}
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
    |> Jason.encode!()
    |> to_charlist()
  end

  defp ssl_opts do
    [
      depth: 3,
      verify: :verify_peer,
      cacertfile: CAStore.file_path(),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end
end
