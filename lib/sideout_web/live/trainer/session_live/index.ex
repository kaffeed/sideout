defmodule SideoutWeb.Trainer.SessionLive.Index do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling
  alias Sideout.Scheduling.Session

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Sideout.PubSub, "sessions:updates")
    end

    {:ok, assign_defaults(socket)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Sessions")
    |> assign(:session, nil)
    |> load_sessions()
  end

  defp apply_action(socket, :new, params) do
    # Pre-fill date if provided in params
    session = %Session{
      date: parse_date(params["date"]),
      fields_available: 1,
      cancellation_deadline_hours: 24,
      status: :scheduled
    }

    socket
    |> assign(:page_title, "New Session")
    |> assign(:session, session)
    |> load_sessions()
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    session = Scheduling.get_session!(id)

    socket
    |> assign(:page_title, "Edit Session")
    |> assign(:session, session)
    |> load_sessions()
  end

  @impl true
  def handle_event("prev_month", _params, socket) do
    current_date = socket.assigns.current_date
    new_date = Date.add(current_date, -30)
    
    {:noreply, 
     socket
     |> assign(:current_date, new_date)
     |> load_sessions()}
  end

  def handle_event("next_month", _params, socket) do
    current_date = socket.assigns.current_date
    new_date = Date.add(current_date, 30)
    
    {:noreply,
     socket
     |> assign(:current_date, new_date)
     |> load_sessions()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    session = Scheduling.get_session!(id)
    {:ok, _} = Scheduling.delete_session(session)

    {:noreply, load_sessions(socket)}
  end

  @impl true
  def handle_info({SideoutWeb.Trainer.SessionLive.FormComponent, {:saved, _session}}, socket) do
    {:noreply, load_sessions(socket)}
  end

  def handle_info({:session_updated, _payload}, socket) do
    {:noreply, load_sessions(socket)}
  end

  defp assign_defaults(socket) do
    today = Date.utc_today()
    
    socket
    |> assign(:current_date, today)
    |> assign(:sessions_by_date, %{})
  end

  defp load_sessions(socket) do
    user = socket.assigns.current_user
    current_date = socket.assigns.current_date
    
    # Get first and last day of the month
    first_day = Date.beginning_of_month(current_date)
    last_day = Date.end_of_month(current_date)
    
    # Load sessions for this month
    sessions = Scheduling.list_sessions(
      user_id: user.id,
      from_date: first_day,
      to_date: last_day,
      preload: [:registrations]
    )
    
    # Group sessions by date
    sessions_by_date = Enum.group_by(sessions, & &1.date)
    
    # Build calendar data
    calendar_data = build_calendar_data(current_date, sessions_by_date)
    
    socket
    |> assign(:sessions_by_date, sessions_by_date)
    |> assign(:calendar_weeks, calendar_data)
    |> assign(:month_name, Calendar.strftime(current_date, "%B %Y"))
  end

  defp build_calendar_data(date, sessions_by_date) do
    first_day = Date.beginning_of_month(date)
    
    # Get the day of week for the first day (1 = Monday, 7 = Sunday)
    first_weekday = Date.day_of_week(first_day)
    
    # Calculate padding days at start (days from previous month)
    padding_start = first_weekday - 1
    
    # Calculate total days to show (6 weeks = 42 days)
    total_days = 42
    
    # Build list of all dates to display
    start_date = Date.add(first_day, -padding_start)
    
    dates = Enum.map(0..(total_days - 1), fn offset ->
      current_date = Date.add(start_date, offset)
      
      %{
        date: current_date,
        in_month: current_date.month == date.month,
        is_today: current_date == Date.utc_today(),
        sessions: Map.get(sessions_by_date, current_date, [])
      }
    end)
    
    # Group into weeks (7 days each)
    Enum.chunk_every(dates, 7)
  end

  defp parse_date(nil), do: Date.utc_today()
  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end

  defp count_registrations(session, status) do
    Enum.count(session.registrations, &(&1.status == status))
  end

  defp capacity_badge_class(session) do
    capacity_status = Scheduling.get_capacity_status(session)
    confirmed = capacity_status.confirmed

    cond do
      confirmed >= 15 -> "bg-green-100 text-green-800 border-green-200"
      confirmed >= 10 -> "bg-yellow-100 text-yellow-800 border-yellow-200"
      true -> "bg-red-100 text-red-800 border-red-200"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <!-- Header -->
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Sessions</h1>
            <p class="mt-2 text-sm text-gray-600">
              Manage your volleyball training sessions
            </p>
          </div>
          <.link
            patch={~p"/trainer/sessions/new"}
            class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
          >
            Create Session
          </.link>
        </div>

        <!-- Calendar Navigation -->
        <div class="mb-6 flex items-center justify-between rounded-lg bg-white px-4 py-3 shadow">
          <button
            phx-click="prev_month"
            class="inline-flex items-center rounded-md px-3 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-100"
          >
            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            Previous
          </button>

          <h2 class="text-lg font-semibold text-gray-900"><%= @month_name %></h2>

          <button
            phx-click="next_month"
            class="inline-flex items-center rounded-md px-3 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-100"
          >
            Next
            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>

        <!-- Calendar Grid -->
        <div class="overflow-hidden rounded-lg bg-white shadow">
          <!-- Day Headers -->
          <div class="grid grid-cols-7 border-b border-gray-200 bg-gray-50 text-center text-xs font-semibold leading-6 text-gray-700">
            <div class="py-2">Mon</div>
            <div class="py-2">Tue</div>
            <div class="py-2">Wed</div>
            <div class="py-2">Thu</div>
            <div class="py-2">Fri</div>
            <div class="py-2">Sat</div>
            <div class="py-2">Sun</div>
          </div>

          <!-- Calendar Body -->
          <div class="grid grid-cols-7 bg-white text-xs leading-6 text-gray-700">
            <%= for week <- @calendar_weeks do %>
              <%= for day <- week do %>
                <div class={[
                  "relative min-h-[120px] border-b border-r border-gray-200 p-2",
                  unless(day.in_month, do: "bg-gray-50"),
                  if(day.is_today, do: "bg-blue-50")
                ]}>
                  <!-- Date Number -->
                  <.link
                    patch={~p"/trainer/sessions/new?date=#{Date.to_iso8601(day.date)}"}
                    class={[
                      "inline-flex h-6 w-6 items-center justify-center rounded-full text-xs font-semibold hover:bg-gray-200",
                      if(day.is_today, do: "bg-indigo-600 text-white hover:bg-indigo-700", else: "text-gray-900")
                    ]}
                  >
                    <%= day.date.day %>
                  </.link>

                  <!-- Sessions for this day -->
                  <div class="mt-1 space-y-1">
                    <%= for session <- Enum.take(day.sessions, 3) do %>
                      <.link
                        navigate={~p"/trainer/sessions/#{session.id}"}
                        class={[
                          "block rounded border px-1.5 py-1 text-xs hover:shadow-sm",
                          capacity_badge_class(session)
                        ]}
                      >
                        <div class="font-semibold">
                          <%= format_time(session.start_time) %>
                        </div>
                        <div class="text-xs">
                          <%= count_registrations(session, :confirmed) %> players
                        </div>
                      </.link>
                    <% end %>

                    <%= if length(day.sessions) > 3 do %>
                      <div class="px-1.5 text-xs font-medium text-gray-500">
                        +<%= length(day.sessions) - 3 %> more
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal for Create/Edit Session -->
    <.modal
      :if={@live_action in [:new, :edit]}
      id="session-modal"
      show
      on_cancel={JS.patch(~p"/trainer/sessions")}
    >
      <.live_component
        module={SideoutWeb.Trainer.SessionLive.FormComponent}
        id={@session.id || :new}
        title={@page_title}
        action={@live_action}
        session={@session}
        current_user={@current_user}
        patch={~p"/trainer/sessions"}
      />
    </.modal>
    """
  end
end
