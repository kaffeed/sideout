defmodule SideoutWeb.Trainer.SessionLive.Show do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling
  alias Sideout.Clubs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    session =
      Scheduling.get_session!(id,
        preload: [
          :user,
          :session_template,
          :club,
          registrations: :player,
          cotrainers: [],
          guest_clubs: [:club]
        ]
      )

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Sideout.PubSub, "sessions:#{id}")
      Phoenix.PubSub.subscribe(Sideout.PubSub, "sessions:updates")
    end

    attendance_stats = Scheduling.get_session_attendance_stats(session)

    # Check if current user is part of this session's club or is a cotrainer
    user = socket.assigns.current_user
    is_club_member = Clubs.is_club_member?(user.id, session.club_id)
    is_cotrainer = Enum.any?(session.cotrainers, &(&1.id == user.id))
    is_session_creator = session.user_id == user.id
    can_join_as_trainer = is_club_member || is_cotrainer || is_session_creator

    # Check if user is already registered as a trainer
    is_registered_as_trainer =
      Enum.any?(session.registrations, fn reg ->
        reg.is_trainer && reg.player.email == user.email
      end)

    {:noreply,
     socket
     |> assign(:page_title, "Session Details")
     |> assign(:session, session)
     |> assign(:show_qr, false)
     |> assign(:copy_success, false)
     |> assign(:attendance_stats, attendance_stats)
     |> assign(:can_join_as_trainer, can_join_as_trainer)
     |> assign(:is_registered_as_trainer, is_registered_as_trainer)
     |> assign_registrations(session)}
  end

  @impl true
  def handle_event("promote", %{"registration_id" => registration_id}, socket) do
    session = socket.assigns.session

    case Integer.parse(registration_id) do
      {id, ""} ->
        registration = Scheduling.get_registration!(id)

        # Manually promote this specific player
        case Scheduling.promote_next_from_waitlist(session, registration.player_id) do
          {:ok, promoted_registration} when not is_nil(promoted_registration) ->
            {:noreply,
             socket
             |> put_flash(:info, "Player promoted to confirmed status")
             |> reload_session()}

          {:ok, nil} ->
            {:noreply,
             socket
             |> put_flash(:error, "Could not promote player - session may be full")
             |> reload_session()}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to promote player")
             |> reload_session()}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_session", _params, socket) do
    {:noreply, assign(socket, :show_cancel_modal, true)}
  end

  def handle_event("confirm_cancel", %{"reason" => reason}, socket) do
    session = socket.assigns.session

    case Scheduling.cancel_session(session, reason) do
      {:ok, _cancelled_session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Session cancelled successfully")
         |> push_navigate(to: ~p"/trainer/sessions")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to cancel session")
         |> assign(:show_cancel_modal, false)}
    end
  end

  def handle_event("close_cancel_modal", _params, socket) do
    {:noreply, assign(socket, :show_cancel_modal, false)}
  end

  def handle_event("toggle_qr", _params, socket) do
    {:noreply, assign(socket, :show_qr, !socket.assigns.show_qr)}
  end

  def handle_event("copy_link", _params, socket) do
    {:noreply,
     socket
     |> assign(:copy_success, true)
     |> push_event("copy-to-clipboard", %{text: share_url(socket.assigns.session)})}
  end

  def handle_event("reset_copy", _params, socket) do
    {:noreply, assign(socket, :copy_success, false)}
  end

  def handle_event("join_as_trainer", _params, socket) do
    session = socket.assigns.session
    user = socket.assigns.current_user

    case Scheduling.register_trainer_participation(session, user.id) do
      {:ok, _registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "You've joined as a trainer")
         |> reload_session()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to join as trainer")
         |> reload_session()}
    end
  end

  def handle_event("leave_as_trainer", _params, socket) do
    session = socket.assigns.session
    user = socket.assigns.current_user

    case Scheduling.unregister_trainer_participation(session, user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "You've left the session")
         |> reload_session()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to leave session")
         |> reload_session()}
    end
  end

  def handle_event("remove_participant", %{"registration_id" => registration_id}, socket) do
    registration = Scheduling.get_registration!(registration_id)

    case Scheduling.cancel_registration(registration, "Removed by trainer") do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Participant removed successfully")
         |> reload_session()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to remove participant")
         |> reload_session()}
    end
  end

  def handle_event("demote_to_waitlist", %{"registration_id" => registration_id}, socket) do
    user = socket.assigns.current_user

    case Scheduling.demote_to_waitlist(String.to_integer(registration_id), user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Participant moved to waitlist")
         |> reload_session()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to move participant to waitlist")
         |> reload_session()}
    end
  end

  @impl true
  def handle_info({:session_updated, _payload}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info({:player_promoted, _payload}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info({:player_cancelled, _payload}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info({:player_registered, _payload}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info({:attendance_marked, _payload}, socket) do
    {:noreply, reload_session(socket)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp reload_session(socket) do
    session =
      Scheduling.get_session!(socket.assigns.session.id,
        preload: [
          :user,
          :session_template,
          :club,
          registrations: :player,
          cotrainers: [],
          guest_clubs: [:club]
        ]
      )

    attendance_stats = Scheduling.get_session_attendance_stats(session)

    # Check if current user is part of this session's club or is a cotrainer
    user = socket.assigns.current_user
    is_club_member = Clubs.is_club_member?(user.id, session.club_id)
    is_cotrainer = Enum.any?(session.cotrainers, &(&1.id == user.id))
    is_session_creator = session.user_id == user.id
    can_join_as_trainer = is_club_member || is_cotrainer || is_session_creator

    # Check if user is already registered as a trainer
    is_registered_as_trainer =
      Enum.any?(session.registrations, fn reg ->
        reg.is_trainer && reg.player.email == user.email
      end)

    socket
    |> assign(:session, session)
    |> assign(:attendance_stats, attendance_stats)
    |> assign(:can_join_as_trainer, can_join_as_trainer)
    |> assign(:is_registered_as_trainer, is_registered_as_trainer)
    |> assign_registrations(session)
  end

  defp assign_registrations(socket, session) do
    all_confirmed = Scheduling.list_registrations(session, :confirmed)
    waitlisted = Scheduling.list_registrations(session, :waitlisted)

    # Separate trainers from regular players
    {trainer_participants, confirmed_registrations} =
      Enum.split_with(all_confirmed, & &1.is_trainer)

    socket
    |> assign(:confirmed_registrations, confirmed_registrations)
    |> assign(:trainer_participants, trainer_participants)
    |> assign(:waitlisted_registrations, waitlisted)
    |> assign(:show_cancel_modal, false)
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end

  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %-d, %Y")
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%b %-d, %Y at %H:%M")
  end

  defp status_badge_class(status) do
    case status do
      :scheduled ->
        "bg-info-100 dark:bg-info-900/30 text-info-800 dark:text-info-400"

      :in_progress ->
        "bg-warning-100 dark:bg-warning-900/30 text-warning-800 dark:text-warning-400"

      :completed ->
        "bg-success-100 dark:bg-success-900/30 text-success-800 dark:text-success-400"

      :cancelled ->
        "bg-danger-100 dark:bg-danger-900/30 text-danger-800 dark:text-danger-400"
    end
  end

  defp status_text(status) do
    status |> Atom.to_string() |> String.capitalize() |> String.replace("_", " ")
  end

  defp share_url(session) do
    uri = SideoutWeb.Endpoint.url()
    "#{uri}/s/#{session.share_token}"
  end

  defp generate_qr_code(session) do
    url = share_url(session)

    try do
      url
      |> EQRCode.encode()
      |> EQRCode.svg(width: 200)
    rescue
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8" phx-hook="CopyToClipboard" id="session-show-container">
      <div class="mx-auto max-w-5xl">
        <!-- Back Button -->
        <div class="mb-6">
          <.link
            navigate={~p"/trainer/sessions"}
            class="inline-flex items-center text-sm font-medium text-neutral-600 hover:text-primary-500 dark:text-neutral-400 dark:hover:text-primary-400 transition-colors"
          >
            <svg class="mr-2 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 19l-7-7 7-7"
              />
            </svg>
            Back to Sessions
          </.link>
        </div>
        
    <!-- Session Header -->
        <div class="mb-8 overflow-hidden rounded-lg bg-white shadow-sporty border-t-4 border-primary-500 dark:bg-secondary-800">
          <div class="px-6 py-5">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="flex items-center gap-3">
                  <h1 class="text-2xl font-bold text-neutral-900 dark:text-neutral-100">
                    {format_date(@session.date)}
                  </h1>
                  <%= if @session.club do %>
                    <span class="inline-flex items-center rounded-full bg-primary-100 px-3 py-1 text-sm font-semibold text-primary-800 dark:bg-primary-900/30 dark:text-primary-400">
                      {@session.club.name}
                    </span>
                  <% end %>
                </div>
                <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
                  {format_time(@session.start_time)} - {format_time(@session.end_time)}
                </p>
              </div>
              <span class={[
                "inline-flex rounded-full px-3 py-1 text-sm font-semibold",
                status_badge_class(@session.status)
              ]}>
                {status_text(@session.status)}
              </span>
            </div>
            
    <!-- Session Info Grid -->
            <div class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-3">
              <div>
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">Capacity</dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100">
                  {Scheduling.get_capacity_status_excluding_trainers(@session).description}
                </dd>
                <dd class="mt-0.5 text-xs text-neutral-500 dark:text-neutral-400">
                  (Excludes trainer participants)
                </dd>
              </div>

              <div>
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">
                  Fields Available
                </dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100">
                  {@session.fields_available}
                </dd>
              </div>

              <div>
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">
                  Cancellation Deadline
                </dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100">
                  {@session.cancellation_deadline_hours} hours before
                </dd>
              </div>
            </div>

            <%= if @session.notes do %>
              <div class="mt-6">
                <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">Notes</dt>
                <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100">
                  {@session.notes}
                </dd>
              </div>
            <% end %>
            
    <!-- Co-trainers Section -->
            <%= if length(@session.cotrainers) > 0 do %>
              <div class="mt-6">
                <h3 class="text-sm font-medium text-neutral-600 dark:text-neutral-400 mb-2">
                  Co-trainers
                </h3>
                <div class="flex flex-wrap gap-2">
                  <%= for cotrainer <- @session.cotrainers do %>
                    <span class="inline-flex items-center gap-1 rounded-full bg-secondary-200 px-3 py-1 text-sm font-medium text-secondary-800 dark:bg-secondary-700 dark:text-secondary-300">
                      <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                        />
                      </svg>
                      {cotrainer.email}
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
            
    <!-- Guest Clubs Section -->
            <%= if length(@session.guest_clubs) > 0 do %>
              <div class="mt-6">
                <h3 class="text-sm font-medium text-neutral-600 dark:text-neutral-400 mb-2">
                  Guest Clubs
                </h3>
                <div class="flex flex-wrap gap-2">
                  <%= for guest_club <- @session.guest_clubs do %>
                    <span class="inline-flex items-center gap-1 rounded-full bg-info-100 px-3 py-1 text-sm font-medium text-info-800 dark:bg-info-900/30 dark:text-info-400">
                      <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                        />
                      </svg>
                      {guest_club.club.name}
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
            
    <!-- Share Link Section -->
            <div class="mt-6 rounded-lg border border-neutral-200 bg-neutral-50 p-4 dark:border-secondary-700 dark:bg-secondary-900">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <h3 class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                    Session Share Link
                  </h3>
                  <p class="mt-1 text-xs text-neutral-600 dark:text-neutral-400">
                    Share this link with players to allow them to register
                  </p>
                  <div class="mt-3 flex items-center gap-2">
                    <input
                      type="text"
                      readonly
                      value={share_url(@session)}
                      class="block flex-1 rounded-md border-neutral-300 bg-white text-sm shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-secondary-600 dark:bg-secondary-800 dark:text-neutral-100"
                      id="share-link-input"
                    />
                    <button
                      phx-click="copy_link"
                      class={[
                        "inline-flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold shadow-md transition-all duration-200",
                        if(@copy_success,
                          do: "bg-success-600 text-white hover:bg-success-500 hover:shadow-lg",
                          else: "bg-primary-500 text-white hover:bg-primary-600 hover:shadow-sporty"
                        )
                      ]}
                    >
                      <%= if @copy_success do %>
                        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M5 13l4 4L19 7"
                          />
                        </svg>
                        Copied!
                      <% else %>
                        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                          />
                        </svg>
                        Copy
                      <% end %>
                    </button>
                    <button
                      phx-click="toggle_qr"
                      class="inline-flex items-center gap-2 rounded-md bg-white px-3 py-2 text-sm font-semibold text-neutral-900 shadow-sm ring-1 ring-inset ring-neutral-300 hover:bg-neutral-50 transition-all duration-200 dark:bg-secondary-700 dark:text-neutral-100 dark:ring-secondary-600 dark:hover:bg-secondary-600"
                    >
                      <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z"
                        />
                      </svg>
                      QR Code
                    </button>
                  </div>
                  <%= if @show_qr do %>
                    <div class="mt-4 flex justify-center rounded-lg border border-neutral-200 bg-white p-4 dark:border-secondary-700 dark:bg-secondary-800">
                      {Phoenix.HTML.raw(generate_qr_code(@session))}
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
            
    <!-- Action Buttons -->
            <div class="mt-6 flex flex-wrap gap-3">
              <.link
                patch={~p"/trainer/sessions/#{@session.id}/edit"}
                class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-neutral-900 shadow-sm ring-1 ring-inset ring-neutral-300 hover:bg-neutral-50 transition-all duration-200 dark:bg-secondary-700 dark:text-neutral-100 dark:ring-secondary-600 dark:hover:bg-secondary-600"
              >
                Edit Session
              </.link>

              <%= if @session.status == :scheduled do %>
                <button
                  phx-click="cancel_session"
                  class="inline-flex items-center rounded-md bg-danger-600 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-danger-500 hover:shadow-lg transition-all duration-200"
                >
                  Cancel Session
                </button>
              <% end %>

              <%= if @can_join_as_trainer && @session.status == :scheduled do %>
                <%= if @is_registered_as_trainer do %>
                  <button
                    phx-click="leave_as_trainer"
                    class="inline-flex items-center gap-2 rounded-md bg-neutral-600 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-neutral-500 hover:shadow-lg transition-all duration-200"
                  >
                    <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                    Leave as Trainer
                  </button>
                <% else %>
                  <button
                    phx-click="join_as_trainer"
                    class="inline-flex items-center gap-2 rounded-md bg-secondary-600 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-secondary-500 hover:shadow-lg transition-all duration-200"
                  >
                    <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"
                      />
                    </svg>
                    Join as Trainer
                  </button>
                <% end %>
              <% end %>

              <.link
                navigate={~p"/trainer/sessions/#{@session.id}/attendance"}
                class="inline-flex items-center rounded-md bg-primary-500 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-primary-600 hover:shadow-sporty transition-all duration-200"
              >
                Mark Attendance
              </.link>
            </div>
          </div>
        </div>
        
    <!-- Attendance Statistics -->
        <%= if @attendance_stats.total_confirmed > 0 do %>
          <div class="mb-8 overflow-hidden rounded-lg bg-white shadow-sporty dark:bg-secondary-800">
            <div class="px-6 py-5">
              <h2 class="text-lg font-semibold text-neutral-900 dark:text-neutral-100 mb-4">
                Attendance Summary
              </h2>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-4">
                <div class="rounded-lg bg-neutral-100 px-4 py-3 dark:bg-secondary-700">
                  <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">
                    Total Confirmed
                  </dt>
                  <dd class="mt-1 text-2xl font-semibold text-neutral-900 dark:text-neutral-100">
                    {@attendance_stats.total_confirmed}
                  </dd>
                </div>

                <div class="rounded-lg bg-success-50 px-4 py-3 dark:bg-success-900/30">
                  <dt class="text-sm font-medium text-success-600 dark:text-success-400">Attended</dt>
                  <dd class="mt-1 text-2xl font-semibold text-success-900 dark:text-success-300">
                    {@attendance_stats.attended}
                  </dd>
                </div>

                <div class="rounded-lg bg-danger-50 px-4 py-3 dark:bg-danger-900/30">
                  <dt class="text-sm font-medium text-danger-600 dark:text-danger-400">No-Shows</dt>
                  <dd class="mt-1 text-2xl font-semibold text-danger-900 dark:text-danger-300">
                    {@attendance_stats.no_shows}
                  </dd>
                </div>

                <div class="rounded-lg bg-info-50 px-4 py-3 dark:bg-info-900/30">
                  <dt class="text-sm font-medium text-info-600 dark:text-info-400">
                    Attendance Rate
                  </dt>
                  <dd class="mt-1 text-2xl font-semibold text-info-900 dark:text-info-300">
                    {@attendance_stats.attendance_rate}%
                  </dd>
                </div>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Trainer Participants -->
        <%= if length(@trainer_participants) > 0 do %>
          <div class="mb-8">
            <div class="mb-4 flex items-center justify-between">
              <h2 class="text-lg font-semibold text-neutral-900 dark:text-neutral-100">
                Trainer Participants ({length(@trainer_participants)})
              </h2>
              <span class="text-xs text-neutral-600 dark:text-neutral-400">
                Trainers don't count toward capacity
              </span>
            </div>

            <div class="overflow-hidden rounded-lg bg-white shadow-sporty dark:bg-secondary-800">
              <ul role="list" class="divide-y divide-neutral-200 dark:divide-secondary-700">
                <%= for registration <- @trainer_participants do %>
                  <li class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div class="flex-1 flex items-center gap-3">
                        <span class="inline-flex items-center rounded-full bg-secondary-200 px-2.5 py-0.5 text-xs font-medium text-secondary-800 dark:bg-secondary-700 dark:text-secondary-300">
                          Trainer
                        </span>
                        <div>
                          <p class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                            {registration.player.name}
                          </p>
                          <p class="text-xs text-neutral-600 dark:text-neutral-400">
                            Registered {format_datetime(registration.registered_at)}
                          </p>
                        </div>
                      </div>
                      <%= if registration.player.email do %>
                        <p class="text-sm text-neutral-600 dark:text-neutral-400 mr-4">
                          {registration.player.email}
                        </p>
                      <% end %>
                      <button
                        phx-click="remove_participant"
                        phx-value-registration_id={registration.id}
                        data-confirm="Remove this trainer participant?"
                        class="inline-flex items-center gap-1 rounded-md bg-danger-600 px-2.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-danger-500 transition-all duration-200"
                      >
                        <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M6 18L18 6M6 6l12 12"
                          />
                        </svg>
                        Remove
                      </button>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        <% end %>
        
    <!-- Confirmed Players -->
        <div class="mb-8">
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-neutral-900 dark:text-neutral-100">
              Confirmed Players ({length(@confirmed_registrations)})
            </h2>
          </div>

          <%= if @confirmed_registrations == [] do %>
            <div class="rounded-lg border-2 border-dashed border-neutral-300 bg-white px-4 py-8 text-center dark:border-secondary-700 dark:bg-secondary-800">
              <p class="text-sm text-neutral-600 dark:text-neutral-400">
                No confirmed registrations yet
              </p>
            </div>
          <% else %>
            <div class="overflow-hidden rounded-lg bg-white shadow-sporty dark:bg-secondary-800">
              <ul role="list" class="divide-y divide-neutral-200 dark:divide-secondary-700">
                <%= for registration <- @confirmed_registrations do %>
                  <li class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <p class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                          {registration.player.name}
                        </p>
                        <p class="text-xs text-neutral-600 dark:text-neutral-400">
                          Registered {format_datetime(registration.registered_at)}
                        </p>
                      </div>
                      <%= if registration.player.email do %>
                        <p class="text-sm text-neutral-600 dark:text-neutral-400 mr-4">
                          {registration.player.email}
                        </p>
                      <% end %>
                      <div class="flex items-center gap-2">
                        <button
                          phx-click="demote_to_waitlist"
                          phx-value-registration_id={registration.id}
                          class="inline-flex items-center gap-1 rounded-md bg-warning-600 px-2.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-warning-500 transition-all duration-200"
                          title="Move to waitlist"
                        >
                          <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M19 14l-7 7m0 0l-7-7m7 7V3"
                            />
                          </svg>
                          Demote
                        </button>
                        <button
                          phx-click="remove_participant"
                          phx-value-registration_id={registration.id}
                          data-confirm="Remove this participant?"
                          class="inline-flex items-center gap-1 rounded-md bg-danger-600 px-2.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-danger-500 transition-all duration-200"
                        >
                          <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M6 18L18 6M6 6l12 12"
                            />
                          </svg>
                          Remove
                        </button>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>
        
    <!-- Waitlist -->
        <div>
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-neutral-900 dark:text-neutral-100">
              Waitlist ({length(@waitlisted_registrations)})
            </h2>
          </div>

          <%= if @waitlisted_registrations == [] do %>
            <div class="rounded-lg border-2 border-dashed border-neutral-300 bg-white px-4 py-8 text-center dark:border-secondary-700 dark:bg-secondary-800">
              <p class="text-sm text-neutral-600 dark:text-neutral-400">No players on waitlist</p>
            </div>
          <% else %>
            <div class="overflow-hidden rounded-lg bg-white shadow-sporty dark:bg-secondary-800">
              <ul role="list" class="divide-y divide-neutral-200 dark:divide-secondary-700">
                <%= for {registration, index} <- Enum.with_index(@waitlisted_registrations, 1) do %>
                  <li class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div class="flex flex-1 items-center gap-4">
                        <div class="flex h-8 w-8 items-center justify-center rounded-full bg-neutral-100 dark:bg-secondary-700">
                          <span class="text-sm font-semibold text-neutral-600 dark:text-neutral-300">
                            #{index}
                          </span>
                        </div>
                        <div class="flex-1">
                          <p class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                            {registration.player.name}
                          </p>
                          <p class="text-xs text-neutral-600 dark:text-neutral-400">
                            Priority Score: {if registration.priority_score,
                              do: Decimal.round(registration.priority_score, 2),
                              else: "N/A"} · Registered {format_datetime(registration.registered_at)}
                          </p>
                        </div>
                      </div>
                      <div class="flex items-center gap-2">
                        <button
                          phx-click="promote"
                          phx-value-registration_id={registration.id}
                          class="inline-flex items-center rounded-md bg-primary-500 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-primary-600 hover:shadow-sporty transition-all duration-200"
                        >
                          Promote
                        </button>
                        <button
                          phx-click="remove_participant"
                          phx-value-registration_id={registration.id}
                          data-confirm="Remove this participant from waitlist?"
                          class="inline-flex items-center gap-1 rounded-md bg-danger-600 px-2.5 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-danger-500 transition-all duration-200"
                        >
                          <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M6 18L18 6M6 6l12 12"
                            />
                          </svg>
                          Remove
                        </button>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Cancel Session Modal -->
    <%= if @show_cancel_modal do %>
      <div class="relative z-50" role="dialog" aria-modal="true">
        <div class="fixed inset-0 bg-neutral-900 bg-opacity-75 transition-opacity"></div>
        <div class="fixed inset-0 z-10 overflow-y-auto">
          <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
            <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6 dark:bg-secondary-800">
              <div class="sm:flex sm:items-start">
                <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-danger-100 sm:mx-0 sm:h-10 sm:w-10 dark:bg-danger-900/30">
                  <svg
                    class="h-6 w-6 text-danger-600 dark:text-danger-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                </div>
                <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left">
                  <h3 class="text-base font-semibold leading-6 text-neutral-900 dark:text-neutral-100">
                    Cancel Session
                  </h3>
                  <div class="mt-2">
                    <p class="text-sm text-neutral-600 dark:text-neutral-400">
                      Are you sure you want to cancel this session? This action cannot be undone.
                      All registered players will need to be notified.
                    </p>
                    <form phx-submit="confirm_cancel" class="mt-4">
                      <label class="block text-sm font-medium text-neutral-700 dark:text-neutral-300">
                        Reason for cancellation
                      </label>
                      <textarea
                        name="reason"
                        rows="3"
                        class="mt-1 block w-full rounded-md border-neutral-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm dark:border-secondary-600 dark:bg-secondary-700 dark:text-neutral-100"
                        placeholder="Optional: provide a reason for cancelling"
                      ></textarea>
                      <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                        <button
                          type="submit"
                          class="inline-flex w-full justify-center rounded-md bg-danger-600 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-danger-500 hover:shadow-lg transition-all duration-200 sm:ml-3 sm:w-auto"
                        >
                          Cancel Session
                        </button>
                        <button
                          type="button"
                          phx-click="close_cancel_modal"
                          class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-neutral-900 shadow-sm ring-1 ring-inset ring-neutral-300 hover:bg-neutral-50 transition-all duration-200 sm:mt-0 sm:w-auto dark:bg-secondary-700 dark:text-neutral-100 dark:ring-secondary-600 dark:hover:bg-secondary-600"
                        >
                          Keep Session
                        </button>
                      </div>
                    </form>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
