defmodule Turnstile.Behaviour do
  @callback site_key :: binary()
  @callback secret_key :: binary()

  @callback refresh(map()) :: map()
  @callback refresh(map(), binary()) :: map()

  @callback remove(map()) :: map()
  @callback remove(map(), binary()) :: map()

  @callback verify(%{binary() => binary()}) :: {:ok, term()} | {:error, term()}
  @callback verify(%{binary() => binary()}, tuple() | binary()) :: {:ok, term()} | {:error, term()}
end
