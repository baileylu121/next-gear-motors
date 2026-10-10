defmodule NextGearMotorsWeb.UserLoginLive do
  use NextGearMotorsWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm px-4 py-16">
      <div class="rounded-2xl border border-zinc-200 bg-white p-8 shadow-card">
        <.header class="text-center">
          Log in to account
          <:subtitle>
            Don't have an account?
            <.link
              navigate={~p"/users/register"}
              class="font-semibold text-raw-sienna-700 hover:underline"
            >
              Sign up
            </.link>
            for an account now.
          </:subtitle>
        </.header>

        <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />

          <:actions>
            <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
            <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
              Forgot your password?
            </.link>
          </:actions>
          <:actions>
            <.button phx-disable-with="Logging in..." class="w-full">
              Log in <span aria-hidden="true">→</span>
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
