defmodule SideoutWeb.HomeLive do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]
    stats = if user, do: Scheduling.get_dashboard_stats(user), else: nil

    {:ok,
     socket
     |> assign(:page_title, "Sideout")
     |> assign(:stats, stats)
     |> assign(:current_user, user)}
  end

  defp format_date(nil), do: "No upcoming sessions"
  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %-d, %Y")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @current_user do %>
      <!-- Authenticated Trainer View -->
      <div class="min-h-screen bg-gray-50">
        <div class="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
          <!-- Welcome Section -->
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-gray-900">
              Welcome back, <%= @current_user.email %>
            </h1>
            <p class="mt-2 text-lg text-gray-600">
              Here's what's happening with your volleyball sessions
            </p>
          </div>

          <!-- Stats Grid -->
          <div class="mb-8 grid gap-6 sm:grid-cols-3">
            <!-- Sessions This Month -->
            <div class="overflow-hidden rounded-lg bg-white shadow">
              <div class="px-6 py-5">
                <div class="flex items-center">
                  <div class="flex-shrink-0 rounded-md bg-indigo-100 p-3">
                    <svg
                      class="h-6 w-6 text-indigo-600"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="truncate text-sm font-medium text-gray-500">
                        Sessions This Month
                      </dt>
                      <dd class="text-3xl font-semibold text-gray-900">
                        <%= @stats.sessions_this_month %>
                      </dd>
                    </dl>
                  </div>
                </div>
              </div>
            </div>

            <!-- Registrations This Week -->
            <div class="overflow-hidden rounded-lg bg-white shadow">
              <div class="px-6 py-5">
                <div class="flex items-center">
                  <div class="flex-shrink-0 rounded-md bg-green-100 p-3">
                    <svg
                      class="h-6 w-6 text-green-600"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                      />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="truncate text-sm font-medium text-gray-500">
                        New Registrations
                      </dt>
                      <dd class="text-3xl font-semibold text-gray-900">
                        <%= @stats.registrations_this_week %>
                      </dd>
                    </dl>
                  </div>
                </div>
              </div>
            </div>

            <!-- Next Session -->
            <div class="overflow-hidden rounded-lg bg-white shadow">
              <div class="px-6 py-5">
                <div class="flex items-center">
                  <div class="flex-shrink-0 rounded-md bg-blue-100 p-3">
                    <svg
                      class="h-6 w-6 text-blue-600"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="truncate text-sm font-medium text-gray-500">Next Session</dt>
                      <dd class="text-sm font-semibold text-gray-900">
                        <%= if @stats.next_session do %>
                          <%= format_date(@stats.next_session.date) %>
                        <% else %>
                          No upcoming sessions
                        <% end %>
                      </dd>
                    </dl>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Quick Actions -->
          <div class="overflow-hidden rounded-lg bg-white shadow">
            <div class="px-6 py-5">
              <h2 class="text-lg font-medium text-gray-900">Quick Actions</h2>
              <div class="mt-4 grid gap-4 sm:grid-cols-3">
                <.link
                  navigate={~p"/trainer/sessions"}
                  class="flex items-center justify-center rounded-lg border-2 border-gray-300 bg-white px-4 py-6 text-center hover:border-indigo-500 hover:bg-gray-50"
                >
                  <div>
                    <svg
                      class="mx-auto h-8 w-8 text-gray-400"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                      />
                    </svg>
                    <p class="mt-2 text-sm font-medium text-gray-900">View Sessions</p>
                  </div>
                </.link>

                <.link
                  navigate={~p"/trainer/templates"}
                  class="flex items-center justify-center rounded-lg border-2 border-gray-300 bg-white px-4 py-6 text-center hover:border-indigo-500 hover:bg-gray-50"
                >
                  <div>
                    <svg
                      class="mx-auto h-8 w-8 text-gray-400"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                      />
                    </svg>
                    <p class="mt-2 text-sm font-medium text-gray-900">Manage Templates</p>
                  </div>
                </.link>

                <.link
                  navigate={~p"/trainer/dashboard"}
                  class="flex items-center justify-center rounded-lg border-2 border-gray-300 bg-white px-4 py-6 text-center hover:border-indigo-500 hover:bg-gray-50"
                >
                  <div>
                    <svg
                      class="mx-auto h-8 w-8 text-gray-400"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                      />
                    </svg>
                    <p class="mt-2 text-sm font-medium text-gray-900">View Dashboard</p>
                  </div>
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% else %>
      <!-- Public View - Login Form -->
      <div class="min-h-screen bg-gradient-to-br from-indigo-900 via-purple-900 to-indigo-800 flex items-center justify-center px-4 py-12 sm:px-6 lg:px-8 relative overflow-hidden">
        <!-- Animated volleyball pattern background -->
        <div class="absolute inset-0 opacity-10">
          <div class="absolute top-20 left-10 w-32 h-32 rounded-full border-4 border-white transform rotate-12"></div>
          <div class="absolute top-40 right-20 w-24 h-24 rounded-full border-4 border-white transform -rotate-45"></div>
          <div class="absolute bottom-32 left-1/4 w-20 h-20 rounded-full border-4 border-white transform rotate-90"></div>
          <div class="absolute bottom-20 right-1/3 w-28 h-28 rounded-full border-4 border-white transform -rotate-12"></div>
        </div>

        <!-- Login Card -->
        <div class="relative w-full max-w-md">
          <!-- Logo/Brand -->
          <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-16 h-16 bg-white rounded-full mb-4 shadow-xl">
              <svg class="w-10 h-10 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <h1 class="text-4xl font-bold text-white tracking-tight">Sideout</h1>
            <p class="mt-2 text-indigo-200 text-lg">Volleyball Session Management</p>
          </div>

          <!-- Login Form Card -->
          <div class="bg-white rounded-2xl shadow-2xl overflow-hidden">
            <div class="px-8 pt-8 pb-6">
              <h2 class="text-2xl font-bold text-gray-900 text-center mb-2">Trainer Login</h2>
              <p class="text-center text-gray-600 text-sm mb-6">Sign in to manage your sessions</p>

              <.form 
                for={%{}}
                as={:user}
                action={~p"/users/log_in"}
                method="post"
                class="space-y-5"
              >
                <!-- Email Field -->
                <div>
                  <label for="email" class="block text-sm font-semibold text-gray-700 mb-2">
                    Email Address
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207" />
                      </svg>
                    </div>
                    <input
                      id="email"
                      name="user[email]"
                      type="email"
                      autocomplete="email"
                      required
                      class="block w-full pl-10 pr-3 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200 text-gray-900 placeholder-gray-400"
                      placeholder="coach@example.com"
                    />
                  </div>
                </div>

                <!-- Password Field -->
                <div>
                  <label for="password" class="block text-sm font-semibold text-gray-700 mb-2">
                    Password
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                      </svg>
                    </div>
                    <input
                      id="password"
                      name="user[password]"
                      type="password"
                      autocomplete="current-password"
                      required
                      class="block w-full pl-10 pr-3 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200 text-gray-900 placeholder-gray-400"
                      placeholder="••••••••"
                    />
                  </div>
                </div>

                <!-- Remember Me & Forgot Password -->
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <input
                      id="remember_me"
                      name="user[remember_me]"
                      type="checkbox"
                      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded cursor-pointer"
                    />
                    <label for="remember_me" class="ml-2 block text-sm text-gray-700 cursor-pointer">
                      Remember me
                    </label>
                  </div>
                  <div class="text-sm">
                    <.link
                      navigate={~p"/users/reset_password"}
                      class="font-medium text-indigo-600 hover:text-indigo-500 transition-colors"
                    >
                      Forgot password?
                    </.link>
                  </div>
                </div>

                <!-- Submit Button -->
                <button
                  type="submit"
                  class="w-full flex justify-center items-center py-3 px-4 border border-transparent rounded-lg shadow-md text-base font-semibold text-white bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-all duration-200 transform hover:scale-[1.02]"
                >
                  Sign in
                  <svg class="ml-2 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                  </svg>
                </button>
              </.form>
            </div>

            <!-- Register Link -->
            <div class="px-8 py-4 bg-gray-50 border-t border-gray-200">
              <p class="text-center text-sm text-gray-600">
                New trainer?
                <.link
                  navigate={~p"/users/register"}
                  class="font-semibold text-indigo-600 hover:text-indigo-500 transition-colors ml-1"
                >
                  Create an account
                </.link>
              </p>
            </div>
          </div>

          <!-- Help Text -->
          <p class="mt-6 text-center text-sm text-indigo-200">
            Players: Use the link shared by your trainer to register for sessions
          </p>
        </div>
      </div>
    <% end %>
    """
  end
end
