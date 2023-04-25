defmodule TurnstileTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Httpc

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Turnstile

  setup do
    ExVCR.Config.cassette_library_dir("test/fixtures/vcr_cassettes", "test/fixtures/custom_cassettes")
    :ok
  end

  test "site_key/0" do
    assert Turnstile.site_key() == "1x00000000000000000000AA"
  end

  test "secret_key/0" do
    assert Turnstile.secret_key() == "1x0000000000000000000000000000000AA"
  end

  describe "script/1" do
    test "should render component with defaults" do
      assert render_component(&Turnstile.script/1) ==
               "<script defer src=\"https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit\"></script>"
    end

    test "should render component with custom attributes" do
      assert render_component(&Turnstile.script/1, foo: "bar") ==
               "<script defer src=\"https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit\" foo=\"bar\"></script>"
    end
  end

  describe "widget/1" do
    test "should render component with defaults" do
      assert render_component(&Turnstile.widget/1) ==
               "<div id=\"cf-turnstile\" phx-hook=\"Turnstile\" phx-update=\"ignore\" data-sitekey=\"1x00000000000000000000AA\"></div>"
    end

    test "should render component with a class" do
      assert render_component(&Turnstile.widget/1, class: "foo") ==
               "<div id=\"cf-turnstile\" phx-hook=\"Turnstile\" phx-update=\"ignore\" data-sitekey=\"1x00000000000000000000AA\" class=\"foo\"></div>"
    end

    test "should render component with a custom id and hook" do
      assert render_component(&Turnstile.widget/1, id: "1", hook: "Foo") ==
               "<div id=\"1\" phx-hook=\"Foo\" phx-update=\"ignore\" data-sitekey=\"1x00000000000000000000AA\"></div>"
    end

    test "should render component with a custom site key" do
      assert render_component(&Turnstile.widget/1, sitekey: "123") ==
               "<div id=\"cf-turnstile\" phx-hook=\"Turnstile\" phx-update=\"ignore\" data-sitekey=\"123\"></div>"
    end

    test "should render component with custom data attribute" do
      assert render_component(&Turnstile.widget/1, theme: "dark") ==
               "<div id=\"cf-turnstile\" phx-hook=\"Turnstile\" phx-update=\"ignore\" data-sitekey=\"1x00000000000000000000AA\" data-theme=\"dark\"></div>"
    end
  end

  test "refresh/2" do
    assert %LiveView.Socket{} = Turnstile.refresh(%LiveView.Socket{})
  end

  test "remove/2" do
    assert %LiveView.Socket{} = Turnstile.remove(%LiveView.Socket{})
  end

  describe "verify/2" do
    test "should return successful status" do
      use_cassette "turnstile_success", custom: true do
        assert Turnstile.verify(%{"cf-turnstile-response" => "foo"}) == {:ok, %{"success" => true}}
      end
    end

    test "should return successful status with ip" do
      use_cassette "turnstile_success", custom: true do
        assert Turnstile.verify(%{"cf-turnstile-response" => "foo"}, "127.0.0.1") == {:ok, %{"success" => true}}
      end
    end

    test "should return successful status with charlist ip" do
      use_cassette "turnstile_success", custom: true do
        assert Turnstile.verify(%{"cf-turnstile-response" => "foo"}, '127.0.0.1') == {:ok, %{"success" => true}}
      end
    end

    test "should return successful status with tuple ip" do
      use_cassette "turnstile_success", custom: true do
        assert Turnstile.verify(%{"cf-turnstile-response" => "foo"}, {127, 0, 0, 1}) == {:ok, %{"success" => true}}
      end
    end

    test "should return unsuccessful status" do
      use_cassette "turnstile_failure", custom: true do
        assert Turnstile.verify(%{"cf-turnstile-response" => "foo"}) == {:error, %{"success" => false}}
      end
    end

    test "should return any other errors" do
      use_cassette "turnstile_error", custom: true do
        assert Turnstile.verify(%{"cf-turnstile-response" => "foo"}) == {:error, "everything broke"}
      end
    end

    @tag :external
    test "should return a successful response" do
      assert {:ok, res} = Turnstile.verify(%{"cf-turnstile-response" => "abc123"})
      assert res["success"] == true
      assert res["error-codes"] == []
    end

    @tag :external
    test "should return a successful response with ip address" do
      assert {:ok, res} = Turnstile.verify(%{"cf-turnstile-response" => "abc123"}, "127.0.0.1")
      assert res["success"] == true
      assert res["error-codes"] == []
    end

    @tag :external
    test "should return an error response" do
      Application.put_env(:phoenix_turnstile, :secret_key, "2x0000000000000000000000000000000AA")
      on_exit(fn -> Application.put_env(:phoenix_turnstile, :secret_key, "1x0000000000000000000000000000000AA") end)

      assert {:error, res} = Turnstile.verify(%{"cf-turnstile-response" => "abc123"}, "127.0.0.1")
      assert res["success"] == false
      assert res["error-codes"] == ["invalid-input-response"]
    end
  end
end
