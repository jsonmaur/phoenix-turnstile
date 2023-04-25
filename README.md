<a href="https://github.com/jsonmaur/phoenix-turnstile/actions/workflows/test.yml"><img alt="Test Status" src="https://img.shields.io/github/actions/workflow/status/jsonmaur/phoenix-turnstile/test.yml?label=&style=for-the-badge&logo=github"></a> <a href="https://hexdocs.pm/phoenix_turnstile/"><img alt="Hex Version" src="https://img.shields.io/hexpm/v/phoenix_turnstile?style=for-the-badge&label=&logo=elixir" /></a>

Phoenix components and helpers for using CAPTCHAs with [Cloudflare Turnstile](https://www.cloudflare.com/products/turnstile/). To get started, log into the Cloudflare dashboard and visit the Turnstile tab. Add a new site with your domain name (no need to add `localhost` if using the default test keys), and take note of your site key and secret key. You'll need these values later.

## Getting Started

```elixir
def deps do
  [
    {:phoenix_turnstile, "~> 1.0"}
  ]
end
```

Now add the site key and secret key to your environment variables, and configure them in `config/runtime.exs`:

```elixir
config :phoenix_turnstile,
  site_key: System.fetch_env!("TURNSTILE_SITE_KEY"),
  secret_key: System.fetch_env!("TURNSTILE_SECRET_KEY")
```

You don't need to add a site key or secret key for dev/test environments. This library will use the Turnstile test keys by default.

## With Live View

To use CAPTCHAs in a Live View app, start out by adding the script component in your root layout:

```heex
<head>
  <!-- ... -->

  <Turnstile.script />
</head>
```

Next, install the hook in `app.js` or wherever your live socket is being defined (make sure you're setting `NODE_PATH` in your [esbuild config](https://github.com/phoenixframework/esbuild#adding-to-phoenix) and including the `deps` folder):

```javascript
import { TurnstileHook } from "phoenix_turnstile"

const liveSocket = new LiveSocket("/live", Socket, {
  /* ... */
  hooks: {
    Turnstile: TurnstileHook
  }
})
```

Now you can use the Turnstile widget component in any of your forms. For example:

```heex
<.form for={@form} phx-submit="submit">
  <Turnstile.widget theme="light" />

  <button type="submit">Submit</button>
</.form>
```

To customize the widget, pass any of the render parameters [specificed here](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configurations) (without the `data-` prefix).

### Verification

The widget by itself won't actually complete the verification. It works by generating a token which gets injected into your form as a hidden input named `cf-turnstile-response`. The token needs to be sent to the Cloudflare API for final verification before continuing with the form submission. This should be done in your submit event using `Turnstile.verify/2`:

```elixir
def handle_event("submit", values, socket) do
  case Turnstile.verify(values) do
    {:ok, _} ->
      # Verification passed!

      {:noreply, socket}

    {:error, _} ->
      socket =
        socket
        |> put_flash(:error, "Please try submitting again")
        |> Turnstile.refresh()

      {:noreply, socket}
  end
end
```

To be extra sure the user is not a robot, you also have the option of passing their IP address to the verification API. **This step is optional.** To get the user's IP address in Live View, add `:peer_data` to the connect info for your socket in `endpoint.ex`:

```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [
    connect_info: [:peer_data, ...]
  ]
```

and pass it as the second argument to `Turnstile.verify/2`:

```elixir
def mount(_params, session, socket) do
  remote_ip = get_connect_info(socket, :peer_data).address

  {:ok, assign(socket, :remote_ip, remote_ip)}
end

def handle_event("submit", values, socket) do
  case Turnstile.verify(values, socket.assigns.remote_ip) do
    # ...
  end
end
```

### Events

The Turnstile widget supports the following events:

* `:success` - When the challenge was successfully completed
* `:error` - When there was an error (like a network error or the challenge failed)
* `:expired` - When the challenge token expires and was not automatically reset
* `:beforeInteractive` - Before the challenge enters interactive mode
* `:afterInteractive` - After the challenge has left interactive mode
* `:unsupported` - When a given client/browser is not supported by Turnstile
* `:timeout` - When the challenge expires (after 5 minutes)

These can be useful for doing things like disabling the submit button until the challenge successfully completes, or refreshing the widget if it fails. To handle an event, add it to the `events` attribute and create a Turnstile event handler in the Live View:

```heex
<Turnstile.widget events={[:success]} />
```

```elixir
handle_event("turnstile:success", _params, socket) do
  # ...

  {:noreply, socket}
end
```

### Multiple Widgets

If you want to have multiple widgets on the same page, pass a unique ID to `Turnstile.widget/1`, `Turnstile.refresh/1`, and `Turnstile.remove/1`.

## Without Live View

`Turnstile.script/1` and `Turnstile.widget/1` both rely on [client hooks](https://hexdocs.pm/phoenix_live_view/js-interop.html#client-hooks-via-phx-hook), and should work in non-Live View pages as long as `app.js` is opening a live socket (which it should by default). Simply call `Turnstile.verify/2` in the controller:

```elixir
def create(conn, params) do
  case Turnstile.verify(params, conn.remote_ip) do
    {:ok, _} ->
      # Verification passed!

      redirect(conn, to: ~p"/success")

    {:error, _} ->
      conn
      |> put_flash(:error, "Please try submitting again")
      |> redirect(to: ~p"/new")
  end
end
```

If your page doesn't open a live socket or your're not using HEEx, you can still run Turnstile verifications by building your own client-side widget following the [documentation](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/) and using `Turnstile.site_key/0` to get your site key in the template:

```elixir
def new(conn, _params) do
  conn
  |> assign(:site_key, Turnstile.site_key())
  |> render("new.html")
end
```

```html
<form action="/create" method="POST">
  <!-- ... -->

  <div class="cf-turnstile" data-sitekey="<%= @site_key %>"></div>
  <button type="submit">Submit</button>
</form>
```

## Content Security Policies

If your site uses a content security policy, you'll need to add `https://challenges.cloudflare.com` to your `script-src` and `frame-src` directives. You can also add attributes to the script component such as `nonce`, and they will be passed through to the script tag:

```heex
<head>
  <!-- ... -->

  <Turnstile.script nonce={@script_src_nonce} />
</head>
```

## Writing Tests

When testing forms that use Turnstile verification, you may or may not want to call the live API.

Although we use the test keys by default, you should consider using mocks during testing. An excellent library to consider is [mox](https://github.com/dashbitco/mox). Phoenix Turnstile exposes a behaviour that you can use to make writing your tests much easier.

To start using Mox with Phoenix Turnstile, add this to your `test/test_helper.ex`:

```elixir
Mox.defmock(TurnstileMock, for: Turnstile.Behaviour)
```

Then in your `config/test.exs`:

```elixir
config :phoenix_turnstile, adapter: TurnstileMock
```

To make sure you're using `TurnstileMock` during testing, use the adapter from the config rather than using `Turnstile` directly:

```elixir
@turnstile Application.compile_env(:phoenix_turnstile, :adapter, Turnstile)

def handle_event("submit", values, socket) do
  case @turnstile.verify(values) do
    {:ok, _} ->
      # Verification passed!

      {:noreply, socket}

    {:error, _} ->
      socket =
        socket
        |> put_flash(:error, "Please try submitting again")
        |> @turnstile.refresh()

      {:noreply, socket}
  end
end
```

Now you can easily mock or stub any Turnstile function in your tests and they won't make any real API calls:

```elixir
import Mox

setup do
  stub(TurnstileMock, :refresh, fn socket -> socket end)
  stub(TurnstileMock, :verify, fn _values, _remoteip -> {:ok, %{}} end)
end
```
