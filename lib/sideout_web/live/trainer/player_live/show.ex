defmodule SideoutWeb.Trainer.PlayerLive.Show do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    player = Scheduling.get_player!(id)
    stats = Scheduling.get_player_stats(player)
    upcoming_registrations = Scheduling.get_player_upcoming_sessions(player)

    # Get registration history (past sessions)
    past_registrations =
      Scheduling.get_player_registration_history(player, limit: 20, status: :past)

    {:noreply,
     socket
     |> assign(:page_title, player.name)
     |> assign(:player, player)
     |> assign(:stats, stats)
     |> assign(:upcoming_registrations, upcoming_registrations)
     |> assign(:past_registrations, past_registrations)}
  end

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end

  defp status_badge_class(:confirmed),
    do:
      "bg-success-50 text-success-700 ring-success-600/20 dark:bg-success-900/30 dark:text-success-400 dark:ring-success-400/20"

  defp status_badge_class(:waitlisted),
    do:
      "bg-warning-50 text-warning-700 ring-warning-600/20 dark:bg-warning-900/30 dark:text-warning-400 dark:ring-warning-400/20"

  defp status_badge_class(:attended),
    do:
      "bg-info-50 text-info-700 ring-info-600/20 dark:bg-info-900/30 dark:text-info-400 dark:ring-info-400/20"

  defp status_badge_class(:no_show),
    do:
      "bg-danger-50 text-danger-700 ring-danger-600/20 dark:bg-danger-900/30 dark:text-danger-400 dark:ring-danger-400/20"

  defp status_badge_class(:cancelled),
    do:
      "bg-neutral-100 text-neutral-700 ring-neutral-600/20 dark:bg-secondary-700 dark:text-neutral-400 dark:ring-neutral-400/20"

  defp status_badge_class(_),
    do:
      "bg-neutral-100 text-neutral-700 ring-neutral-600/20 dark:bg-secondary-700 dark:text-neutral-400 dark:ring-neutral-400/20"

  defp status_text(status) do
    status |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <!-- Header with back button -->
        <div class="mb-6">
          <.link
            navigate={~p"/trainer/players"}
            class="text-sm font-medium text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
          >
            ← Back to Players
          </.link>
        </div>
        
    <!-- Player Info Card -->
        <div class="mb-8 overflow-hidden bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 flex justify-between items-start">
            <div>
              <h1 class="text-3xl font-bold text-neutral-900 dark:text-neutral-100">
                {@player.name}
              </h1>
              <div class="mt-2 space-y-1">
                <%= if @player.email do %>
                  <p class="text-sm text-neutral-600 dark:text-neutral-400">
                    <span class="font-medium">Email:</span>
                    {@player.email}
                  </p>
                <% end %>
                <%= if @player.phone do %>
                  <p class="text-sm text-neutral-600 dark:text-neutral-400">
                    <span class="font-medium">Phone:</span>
                    {@player.phone}
                  </p>
                <% end %>
              </div>
            </div>
            <div class="flex gap-2">
              <.link
                patch={~p"/trainer/players/#{@player.id}/edit"}
                class="rounded-md bg-white dark:bg-secondary-700 px-3 py-2 text-sm font-semibold text-neutral-900 dark:text-neutral-100 shadow-sm ring-1 ring-inset ring-neutral-300 dark:ring-secondary-600 hover:bg-neutral-50 dark:hover:bg-secondary-600 transition-colors"
              >
                Edit
              </.link>
            </div>
          </div>

          <%= if @player.notes do %>
            <div class="border-t border-neutral-200 dark:border-secondary-700 px-4 py-5 sm:px-6">
              <h3 class="text-sm font-medium text-neutral-900 dark:text-neutral-100 mb-2">Notes</h3>
              <p class="text-sm text-neutral-600 dark:text-neutral-400 whitespace-pre-wrap">
                {@player.notes}
              </p>
            </div>
          <% end %>
        </div>
        
    <!-- Statistics Cards -->
        <div class="mb-8 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <!-- Total Sessions -->
          <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 px-4 py-5 sm:p-6 transition-all duration-200 hover:shadow-sporty-lg">
            <dt class="truncate text-sm font-medium text-neutral-500 dark:text-neutral-400">
              Total Sessions
            </dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-neutral-900 dark:text-neutral-100">
              {@stats.total_sessions}
            </dd>
          </div>
          
    <!-- Completed Sessions -->
          <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 px-4 py-5 sm:p-6 transition-all duration-200 hover:shadow-sporty-lg">
            <dt class="truncate text-sm font-medium text-neutral-500 dark:text-neutral-400">
              Completed Sessions
            </dt>
            <dd class="mt-1 text-3xl font-semibold tracking-tight text-neutral-900 dark:text-neutral-100">
              {@stats.completed_sessions}
            </dd>
          </div>
          
    <!-- Attendance Rate -->
          <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 px-4 py-5 sm:p-6 transition-all duration-200 hover:shadow-sporty-lg">
            <dt class="truncate text-sm font-medium text-neutral-500 dark:text-neutral-400">
              Attendance Rate
            </dt>
            <dd class={[
              "mt-1 text-3xl font-semibold tracking-tight",
              if(@stats.attendance_rate >= 80,
                do: "text-success-600 dark:text-success-400",
                else: "text-warning-600 dark:text-warning-400"
              )
            ]}>
              {@stats.attendance_rate}%
            </dd>
            <p class="mt-1 text-xs text-neutral-500 dark:text-neutral-400">
              {@stats.attended} attended / {@stats.completed_sessions} total
            </p>
          </div>
          
    <!-- No-Show Rate -->
          <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 px-4 py-5 sm:p-6 transition-all duration-200 hover:shadow-sporty-lg">
            <dt class="truncate text-sm font-medium text-neutral-500 dark:text-neutral-400">
              No-Show Rate
            </dt>
            <dd class={[
              "mt-1 text-3xl font-semibold tracking-tight",
              if(@stats.no_show_rate <= 10,
                do: "text-success-600 dark:text-success-400",
                else: "text-danger-600 dark:text-danger-400"
              )
            ]}>
              {@stats.no_show_rate}%
            </dd>
            <p class="mt-1 text-xs text-neutral-500 dark:text-neutral-400">
              {@stats.no_shows} no-shows / {@stats.completed_sessions} total
            </p>
          </div>
        </div>
        
    <!-- Upcoming Sessions -->
        <div class="mb-8">
          <h2 class="text-xl font-bold text-neutral-900 dark:text-neutral-100 mb-4">
            Upcoming Sessions
          </h2>
          <%= if @upcoming_registrations == [] do %>
            <div class="rounded-lg bg-neutral-50 dark:bg-secondary-800 px-4 py-12 text-center">
              <p class="text-sm text-neutral-600 dark:text-neutral-400">No upcoming sessions</p>
            </div>
          <% else %>
            <div class="overflow-hidden bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 sm:rounded-lg">
              <table class="min-w-full divide-y divide-neutral-300 dark:divide-secondary-700">
                <thead class="bg-neutral-50 dark:bg-secondary-900">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100 sm:pl-6"
                    >
                      Date & Time
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100"
                    >
                      Template
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100"
                    >
                      Status
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-neutral-200 dark:divide-secondary-700 bg-white dark:bg-secondary-800">
                  <%= for registration <- @upcoming_registrations do %>
                    <tr class="hover:bg-neutral-50 dark:hover:bg-secondary-700 transition-colors">
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm text-neutral-900 dark:text-neutral-100 sm:pl-6">
                        {format_date(registration.session.date)}<br />
                        <span class="text-neutral-500 dark:text-neutral-400">
                          {format_time(registration.session.start_time)} - {format_time(
                            registration.session.end_time
                          )}
                        </span>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-neutral-500 dark:text-neutral-400">
                        <%= if registration.session.session_template do %>
                          {registration.session.session_template.name}
                        <% else %>
                          <span class="text-neutral-400 dark:text-neutral-500">One-off session</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <span class={[
                          "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ring-1 ring-inset",
                          status_badge_class(registration.status)
                        ]}>
                          {status_text(registration.status)}
                        </span>
                        <%= if registration.status == :waitlisted && registration.priority_score do %>
                          <span class="ml-2 text-xs text-neutral-500 dark:text-neutral-400">
                            Priority: {Decimal.round(registration.priority_score, 1)}
                          </span>
                        <% end %>
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <.link
                          navigate={~p"/trainer/sessions/#{registration.session.id}"}
                          class="text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
                        >
                          View Session
                        </.link>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
        
    <!-- Registration History -->
        <div class="mb-8">
          <h2 class="text-xl font-bold text-neutral-900 dark:text-neutral-100 mb-4">
            Registration History
          </h2>
          <%= if @past_registrations == [] do %>
            <div class="rounded-lg bg-neutral-50 dark:bg-secondary-800 px-4 py-12 text-center">
              <p class="text-sm text-neutral-600 dark:text-neutral-400">No past sessions</p>
            </div>
          <% else %>
            <div class="overflow-hidden bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 sm:rounded-lg">
              <table class="min-w-full divide-y divide-neutral-300 dark:divide-secondary-700">
                <thead class="bg-neutral-50 dark:bg-secondary-900">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100 sm:pl-6"
                    >
                      Date & Time
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100"
                    >
                      Template
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100"
                    >
                      Status
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-neutral-200 dark:divide-secondary-700 bg-white dark:bg-secondary-800">
                  <%= for registration <- @past_registrations do %>
                    <tr class="hover:bg-neutral-50 dark:hover:bg-secondary-700 transition-colors">
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm text-neutral-900 dark:text-neutral-100 sm:pl-6">
                        {format_date(registration.session.date)}<br />
                        <span class="text-neutral-500 dark:text-neutral-400">
                          {format_time(registration.session.start_time)} - {format_time(
                            registration.session.end_time
                          )}
                        </span>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-neutral-500 dark:text-neutral-400">
                        <%= if registration.session.session_template do %>
                          {registration.session.session_template.name}
                        <% else %>
                          <span class="text-neutral-400 dark:text-neutral-500">One-off session</span>
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <span class={[
                          "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ring-1 ring-inset",
                          status_badge_class(registration.status)
                        ]}>
                          {status_text(registration.status)}
                        </span>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
