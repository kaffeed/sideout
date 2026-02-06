defmodule SideoutWeb.SessionSignupLive do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(%{"share_token" => token}, _session, socket) do
    case Scheduling.get_session_by_share_token(token,
           preload: [:session_template, :user, registrations: :player]
         ) do
      nil ->
        {:ok,
         socket
         |> assign(:error_type, get_error_type(token))
         |> assign(:page_title, "Session Not Found")}

      session ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Sideout.PubSub, "sessions:updates")
          Phoenix.PubSub.subscribe(Sideout.PubSub, "session:#{session.id}")
        end

        {:ok,
         socket
         |> assign(:session, session)
         |> assign(:error_type, nil)
         |> assign(:capacity_info, capacity_info(session))
         |> assign(:page_title, "Register for Session")
         |> assign(:form, to_form(%{"player_name" => "", "email" => "", "phone" => ""}))
         |> assign(:registration_result, nil)
         |> assign(:errors, [])
         |> assign(:user_registration, nil)
         |> assign(:cached_data_loaded, false)}
    end
  end

  @impl true
  def handle_event(
        "register",
        %{"player_name" => name, "email" => email, "phone" => phone},
        socket
      ) do
    session = socket.assigns.session

    # Validate required fields
    if String.trim(name) == "" do
      {:noreply, assign(socket, :errors, ["Name is required"])}
    else
      # Get or create player (associate with session's club)
      player_attrs = %{
        "name" => String.trim(name),
        "email" => if(String.trim(email) != "", do: String.trim(email), else: nil),
        "phone" => if(String.trim(phone) != "", do: String.trim(phone), else: nil),
        "club_id" => session.club_id
      }

      case Scheduling.get_or_create_player_by_name(player_attrs["name"], player_attrs) do
        {:ok, player} ->
          # Check if player is already registered
          case check_existing_registration(session, player) do
            {:ok, :not_registered} ->
              # Register the player
              case Scheduling.register_player(session, player) do
                {:ok, registration} ->
                  require Logger

                  Logger.info(
                    "Registration successful - player: #{player.name}, token: #{registration.cancellation_token}"
                  )

                  # Update user_registration to show cancel button
                  socket =
                    socket
                    |> assign(
                      :form,
                      to_form(%{"player_name" => player.name, "email" => "", "phone" => ""})
                    )
                    |> assign(:registration_result, {:success, registration})
                    |> assign(:user_registration, registration)
                    |> assign(:errors, [])
                    |> reload_session()

                  # Save player name to localStorage
                  Logger.info("Pushing save_player_name event with name: #{player.name}")

                  socket =
                    Phoenix.LiveView.push_event(socket, "save_player_name", %{name: player.name})

                  # Save cancellation token to localStorage
                  socket =
                    if registration.cancellation_token do
                      Logger.info(
                        "Pushing save_cancellation_token event - session: #{session.id}, token: #{registration.cancellation_token}"
                      )

                      Phoenix.LiveView.push_event(socket, "save_cancellation_token", %{
                        session_id: session.id,
                        token: registration.cancellation_token
                      })
                    else
                      Logger.warning("No cancellation token found for registration!")
                      socket
                    end

                  {:noreply, socket}

                {:error, changeset} ->
                  errors = extract_errors(changeset)
                  {:noreply, assign(socket, :errors, errors)}
              end

            {:error, message} ->
              {:noreply, assign(socket, :errors, [message])}
          end

        {:error, changeset} ->
          errors = extract_errors(changeset)
          {:noreply, assign(socket, :errors, errors)}
      end
    end
  end

  def handle_event("clear_result", _params, socket) do
    {:noreply, assign(socket, :registration_result, nil)}
  end

  def handle_event(
        "load_cached_data",
        %{"name" => cached_name, "cancellation_token" => cancellation_token},
        socket
      ) do
    require Logger

    Logger.info(
      "load_cached_data called with name: #{cached_name}, token: #{inspect(cancellation_token)}"
    )

    # Only process once to avoid race conditions
    if socket.assigns.cached_data_loaded do
      Logger.info("cached_data_loaded already true, skipping")
      {:noreply, socket}
    else
      socket = assign(socket, :cached_data_loaded, true)

      # Pre-fill name in form if available
      socket =
        if cached_name != "" do
          Logger.info("Pre-filling form with name: #{cached_name}")

          assign(
            socket,
            :form,
            to_form(%{"player_name" => cached_name, "email" => "", "phone" => ""})
          )
        else
          Logger.info("No cached name to pre-fill")
          socket
        end

      # Check if user is already registered
      user_registration =
        detect_existing_registration(socket.assigns.session, cancellation_token, cached_name)

      Logger.info("User registration detected: #{inspect(user_registration != nil)}")

      if user_registration do
        Logger.info(
          "Registration found - ID: #{user_registration.id}, Status: #{user_registration.status}"
        )
      end

      {:noreply, assign(socket, :user_registration, user_registration)}
    end
  end

  def handle_event("cancel_registration", _params, socket) do
    case socket.assigns.user_registration do
      nil ->
        {:noreply, socket}

      registration ->
        case Scheduling.cancel_registration(registration, %{
               cancellation_reason: "Cancelled via sign-up page"
             }) do
          {:ok, _cancelled_registration} ->
            # Get cached name to pre-fill form
            cached_name = socket.assigns.form[:player_name].value || ""

            socket =
              socket
              |> assign(:user_registration, nil)
              |> assign(
                :registration_result,
                {:cancelled, "Your registration has been cancelled"}
              )
              |> assign(
                :form,
                to_form(%{"player_name" => cached_name, "email" => "", "phone" => ""})
              )
              |> assign(:errors, [])
              |> reload_session()
              |> Phoenix.LiveView.push_event("clear_cancellation_token", %{
                session_id: socket.assigns.session.id
              })

            {:noreply, socket}

          {:error, changeset} ->
            errors = extract_errors(changeset)
            {:noreply, assign(socket, :errors, errors)}
        end
    end
  end

  @impl true
  def handle_info({:session_updated, payload}, socket) do
    if socket.assigns.error_type == nil && payload.session_id == socket.assigns.session.id do
      socket = reload_session(socket)

      # Re-check if user is still registered after session update
      user_registration =
        if socket.assigns.user_registration do
          # Re-fetch the registration to get updated status
          updated_reg =
            Enum.find(socket.assigns.session.registrations, fn reg ->
              reg.id == socket.assigns.user_registration.id
            end)

          # Only keep it if still active
          if updated_reg && updated_reg.status in [:confirmed, :waitlisted] do
            updated_reg
          else
            nil
          end
        else
          socket.assigns.user_registration
        end

      {:noreply, assign(socket, :user_registration, user_registration)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:registration_changed, _payload}, socket) do
    if socket.assigns.error_type == nil do
      socket = reload_session(socket)

      # Re-check if user is still registered after registration change
      user_registration =
        if socket.assigns.user_registration do
          updated_reg =
            Enum.find(socket.assigns.session.registrations, fn reg ->
              reg.id == socket.assigns.user_registration.id
            end)

          if updated_reg && updated_reg.status in [:confirmed, :waitlisted] do
            updated_reg
          else
            nil
          end
        else
          socket.assigns.user_registration
        end

      {:noreply, assign(socket, :user_registration, user_registration)}
    else
      {:noreply, socket}
    end
  end

  defp reload_session(socket) do
    session =
      Scheduling.get_session!(socket.assigns.session.id,
        preload: [:session_template, :user, registrations: :player]
      )

    socket
    |> assign(:session, session)
    |> assign(:capacity_info, capacity_info(session))
  end

  defp detect_existing_registration(session, cancellation_token, cached_name) do
    require Logger

    Logger.info(
      "detect_existing_registration - session_id: #{session.id}, token: #{inspect(cancellation_token)}, name: #{cached_name}"
    )

    # Strategy 1: Try to find by cancellation token (most reliable)
    registration_by_token =
      if cancellation_token && cancellation_token != "" do
        Logger.info("Checking registration by token: #{cancellation_token}")

        case Scheduling.get_registration_by_token(cancellation_token) do
          nil ->
            Logger.info("No registration found for token")
            nil

          reg ->
            Logger.info(
              "Found registration by token - ID: #{reg.id}, session_id: #{reg.session_id}, status: #{reg.status}"
            )

            # Verify it's for this session and is active
            if reg.session_id == session.id && reg.status in [:confirmed, :waitlisted] do
              Logger.info("Token registration is valid for this session")
              reg
            else
              Logger.info("Token registration is NOT valid (wrong session or cancelled)")
              nil
            end
        end
      else
        Logger.info("No cancellation token provided, skipping token check")
        nil
      end

    # Strategy 2: Fall back to name matching if token check failed
    registration_by_name =
      if is_nil(registration_by_token) && cached_name != "" do
        Logger.info("Falling back to name matching: #{cached_name}")
        Logger.info("Session has #{length(session.registrations)} registrations")

        found =
          Enum.find(session.registrations, fn reg ->
            String.downcase(reg.player.name) == String.downcase(String.trim(cached_name)) &&
              reg.status in [:confirmed, :waitlisted]
          end)

        if found do
          Logger.info(
            "Found registration by name - ID: #{found.id}, player: #{found.player.name}"
          )
        else
          Logger.info("No registration found by name")
        end

        found
      else
        Logger.info("Skipping name matching (token found or no cached name)")
        nil
      end

    # Return whichever match we found
    result = registration_by_token || registration_by_name
    Logger.info("Final detection result: #{inspect(result != nil)}")
    result
  end

  defp get_error_type(token) do
    if Sideout.Scheduling.ShareToken.valid?(token) do
      # Token is valid format, check if it exists or is expired
      case Sideout.Repo.get_by(Sideout.Scheduling.Session, share_token: token) do
        nil ->
          :invalid_token

        %{status: :cancelled} ->
          :cancelled_session

        %{status: :completed} ->
          :expired_session

        %{date: date} ->
          if Date.compare(date, Date.utc_today()) == :lt do
            :expired_session
          else
            :invalid_token
          end
      end
    else
      :invalid_token
    end
  end

  defp check_existing_registration(session, player) do
    existing =
      Enum.find(session.registrations, fn reg ->
        reg.player_id == player.id && reg.status in [:confirmed, :waitlisted]
      end)

    case existing do
      nil ->
        {:ok, :not_registered}

      reg ->
        status_text = if reg.status == :confirmed, do: "confirmed", else: "waitlisted"
        {:error, "You are already registered for this session (#{status_text})"}
    end
  end

  defp extract_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end

  defp capacity_info(session) do
    capacity_status = Scheduling.get_capacity_status(session)
    max_capacity = Scheduling.get_max_capacity(session)

    %{
      confirmed: capacity_status.confirmed,
      max: max_capacity,
      waitlisted: capacity_status.waitlist,
      spots_available: max_capacity - capacity_status.confirmed,
      is_full: capacity_status.confirmed >= max_capacity
    }
  end

  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp format_time(time) do
    Calendar.strftime(time, "%I:%M %p")
  end

  defp skill_level_text(session) do
    if session.session_template do
      session.session_template.skill_level
      |> to_string()
      |> String.capitalize()
    else
      "Mixed"
    end
  end

  defp confirmed_registrations(session) do
    Enum.filter(session.registrations, &(&1.status == :confirmed))
    |> Enum.sort_by(& &1.registered_at)
  end

  defp waitlisted_registrations(session) do
    Enum.filter(session.registrations, &(&1.status == :waitlisted))
    |> Enum.sort_by(& &1.priority_score, :desc)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="session-signup-container"
      phx-hook="PlayerCache"
      data-session-id={if @error_type == nil && assigns[:session], do: @session.id, else: ""}
    >
      <%= if @error_type do %>
        <div class="min-h-screen bg-neutral-50 dark:bg-secondary-900 flex items-center justify-center px-4">
          <div class="max-w-md w-full">
            <div class="text-center">
              <svg
                class="mx-auto h-12 w-12 text-danger-400"
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

              <h2 class="mt-6 text-2xl font-bold text-neutral-900 dark:text-neutral-100">
                <%= case @error_type do %>
                  <% :invalid_token -> %>
                    Session Not Found
                  <% :expired_session -> %>
                    Session Expired
                  <% :cancelled_session -> %>
                    Session Cancelled
                <% end %>
              </h2>

              <p class="mt-2 text-sm text-neutral-600 dark:text-neutral-400">
                <%= case @error_type do %>
                  <% :invalid_token -> %>
                    This session link is invalid or doesn't exist. Please check the link and try again.
                  <% :expired_session -> %>
                    This session has already passed. Registration is no longer available.
                  <% :cancelled_session -> %>
                    This session has been cancelled by the trainer.
                <% end %>
              </p>

              <div class="mt-6">
                <p class="text-sm text-neutral-500 dark:text-neutral-400">
                  If you believe this is an error, please contact the session organizer.
                </p>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="min-h-screen bg-neutral-50 dark:bg-secondary-900">
          <!-- Header -->
          <div class="bg-white dark:bg-secondary-800 shadow-md border-t-4 border-primary-500">
            <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
              <div class="md:flex md:items-center md:justify-between">
                <div class="min-w-0 flex-1">
                  <h1 class="text-3xl font-bold text-neutral-900 dark:text-neutral-100">
                    Session Registration
                  </h1>
                </div>
              </div>
            </div>
          </div>

          <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
            <div class="grid gap-8 lg:grid-cols-3">
              <!-- Session Information (Left Column) -->
              <div class="lg:col-span-2 space-y-6">
                <!-- Main Info Card -->
                <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500">
                  <div class="px-6 py-5">
                    <div class="flex items-start justify-between">
                      <div>
                        <h2 class="text-2xl font-bold text-neutral-900 dark:text-neutral-100">
                          {format_date(@session.date)}
                        </h2>
                        <p class="mt-1 text-lg text-neutral-600 dark:text-neutral-400">
                          {format_time(@session.start_time)} - {format_time(@session.end_time)}
                        </p>
                      </div>
                      <span class={[
                        "inline-flex items-center rounded-full px-3 py-1 text-sm font-medium",
                        if(@capacity_info.is_full,
                          do:
                            "bg-danger-100 text-danger-800 dark:bg-danger-900/30 dark:text-danger-400",
                          else:
                            "bg-success-100 text-success-800 dark:bg-success-900/30 dark:text-success-400"
                        )
                      ]}>
                        {if @capacity_info.is_full, do: "Full", else: "Open"}
                      </span>
                    </div>

                    <dl class="mt-6 grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
                      <div>
                        <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">
                          Skill Level
                        </dt>
                        <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100">
                          {skill_level_text(@session)}
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
                          Capacity
                        </dt>
                        <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100">
                          {@capacity_info.confirmed} / {@capacity_info.max} players
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
                    </dl>

                    <%= if @session.notes do %>
                      <div class="mt-6">
                        <dt class="text-sm font-medium text-neutral-600 dark:text-neutral-400">
                          Session Notes
                        </dt>
                        <dd class="mt-1 text-sm text-neutral-900 dark:text-neutral-100">
                          {@session.notes}
                        </dd>
                      </div>
                    <% end %>
                  </div>
                </div>
                
    <!-- Registered Players -->
                <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty">
                  <div class="px-6 py-5">
                    <h3 class="text-lg font-medium text-neutral-900 dark:text-neutral-100">
                      Confirmed Players ({length(confirmed_registrations(@session))})
                    </h3>
                    <div class="mt-4">
                      <%= if Enum.empty?(confirmed_registrations(@session)) do %>
                        <p class="text-sm text-neutral-600 dark:text-neutral-400">
                          No players registered yet
                        </p>
                      <% else %>
                        <ul class="divide-y divide-neutral-200 dark:divide-secondary-700">
                          <%= for registration <- confirmed_registrations(@session) do %>
                            <li class="py-3">
                              <div class="flex items-center justify-between">
                                <span class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                                  {registration.player.name}
                                </span>
                                <span class="text-xs text-neutral-600 dark:text-neutral-400">
                                  Registered {Calendar.strftime(registration.registered_at, "%b %d")}
                                </span>
                              </div>
                            </li>
                          <% end %>
                        </ul>
                      <% end %>
                    </div>
                  </div>
                </div>
                
    <!-- Waitlist -->
                <%= if @capacity_info.waitlisted > 0 do %>
                  <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty">
                    <div class="px-6 py-5">
                      <h3 class="text-lg font-medium text-neutral-900 dark:text-neutral-100">
                        Waitlist ({@capacity_info.waitlisted})
                      </h3>
                      <div class="mt-4">
                        <ul class="divide-y divide-neutral-200 dark:divide-secondary-700">
                          <%= for {registration, index} <- Enum.with_index(waitlisted_registrations(@session), 1) do %>
                            <li class="py-3">
                              <div class="flex items-center justify-between">
                                <div>
                                  <span class="text-xs font-medium text-neutral-600 dark:text-neutral-400 mr-2">
                                    #{index}
                                  </span>
                                  <span class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                                    {registration.player.name}
                                  </span>
                                </div>
                                <span class="text-xs text-neutral-600 dark:text-neutral-400">
                                  Priority: {Decimal.round(registration.priority_score || 0, 1)}
                                </span>
                              </div>
                            </li>
                          <% end %>
                        </ul>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
              
    <!-- Registration Form (Right Column) -->
              <div class="lg:col-span-1">
                <div class="sticky top-8">
                  <!-- Success Message -->
                  <%= if @registration_result do %>
                    <div class="mb-6 rounded-lg bg-success-50 dark:bg-success-900/30 p-4 border-t-4 border-success-600">
                      <div class="flex">
                        <div class="flex-shrink-0">
                          <svg
                            class="h-5 w-5 text-success-400"
                            viewBox="0 0 20 20"
                            fill="currentColor"
                          >
                            <path
                              fill-rule="evenodd"
                              d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </div>
                        <div class="ml-3">
                          <%= if match?({:success, _}, @registration_result) do %>
                            <% {_, registration} = @registration_result %>
                            <h3 class="text-sm font-medium text-success-800 dark:text-success-400">
                              <%= if registration.status == :confirmed do %>
                                Successfully Registered!
                              <% else %>
                                Added to Waitlist
                              <% end %>
                            </h3>
                            <div class="mt-2 text-sm text-success-700 dark:text-success-300">
                              <p>
                                <%= if registration.status == :confirmed do %>
                                  You're confirmed for this session.
                                <% else %>
                                  You're on the waitlist. We'll notify you if a spot opens up.
                                <% end %>
                              </p>
                            </div>
                          <% else %>
                            <% {_, message} = @registration_result %>
                            <h3 class="text-sm font-medium text-success-800 dark:text-success-400">
                              Registration Cancelled
                            </h3>
                            <div class="mt-2 text-sm text-success-700 dark:text-success-300">
                              <p>{message}</p>
                            </div>
                          <% end %>
                          <button
                            phx-click="clear_result"
                            class="mt-3 text-sm font-medium text-success-800 dark:text-success-400 underline hover:text-success-900 dark:hover:text-success-300"
                          >
                            Dismiss
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>
                  
    <!-- Error Messages -->
                  <%= if !Enum.empty?(@errors) do %>
                    <div class="mb-6 rounded-lg bg-danger-50 dark:bg-danger-900/30 p-4 border-t-4 border-danger-600">
                      <div class="flex">
                        <div class="flex-shrink-0">
                          <svg class="h-5 w-5 text-danger-400" viewBox="0 0 20 20" fill="currentColor">
                            <path
                              fill-rule="evenodd"
                              d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </div>
                        <div class="ml-3">
                          <h3 class="text-sm font-medium text-danger-800 dark:text-danger-400">
                            Registration Error
                          </h3>
                          <div class="mt-2 text-sm text-danger-700 dark:text-danger-300">
                            <ul class="list-disc space-y-1 pl-5">
                              <%= for error <- @errors do %>
                                <li>{error}</li>
                              <% end %>
                            </ul>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                  
    <!-- Registration Form -->
                  <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500">
                    <%= if @user_registration do %>
                      <!-- Already Registered - Show Cancel Button -->
                      <div class="px-6 py-5">
                        <h3 class="text-lg font-medium text-neutral-900 dark:text-neutral-100">
                          You're Registered!
                        </h3>
                        <div class="mt-4 space-y-4">
                          <div class="bg-success-50 dark:bg-success-900/20 rounded-md p-4 border border-success-200 dark:border-success-800">
                            <div class="flex items-start">
                              <svg
                                class="h-5 w-5 text-success-500 mt-0.5"
                                fill="currentColor"
                                viewBox="0 0 20 20"
                              >
                                <path
                                  fill-rule="evenodd"
                                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                                  clip-rule="evenodd"
                                />
                              </svg>
                              <div class="ml-3">
                                <p class="text-sm font-medium text-success-800 dark:text-success-400">
                                  {@user_registration.player.name}
                                </p>
                                <p class="mt-1 text-sm text-success-700 dark:text-success-300">
                                  Status: {if @user_registration.status == :confirmed,
                                    do: "Confirmed",
                                    else: "Waitlisted"}
                                </p>
                                <%= if @user_registration.status == :waitlisted do %>
                                  <p class="mt-1 text-xs text-success-600 dark:text-success-400">
                                    Position: #{Enum.find_index(
                                      waitlisted_registrations(@session),
                                      &(&1.id == @user_registration.id)
                                    )
                                    |> Kernel.+(1)}
                                  </p>
                                <% end %>
                              </div>
                            </div>
                          </div>

                          <button
                            phx-click="cancel_registration"
                            class="w-full rounded-md bg-danger-500 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-danger-600 hover:shadow-sporty focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-danger-600 transition-all duration-200"
                          >
                            Cancel Registration
                          </button>

                          <p class="text-xs text-neutral-600 dark:text-neutral-400 text-center">
                            Cancellation deadline: {@session.cancellation_deadline_hours} hours before session
                          </p>
                        </div>
                      </div>
                    <% else %>
                      <!-- Not Registered - Show Sign-up Form -->
                      <div class="px-6 py-5">
                        <h3 class="text-lg font-medium text-neutral-900 dark:text-neutral-100">
                          Register for Session
                        </h3>
                        <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
                          <%= if @capacity_info.is_full do %>
                            Session is full. You will be added to the waitlist.
                          <% else %>
                            {@capacity_info.spots_available} spot{if @capacity_info.spots_available !=
                                                                       1, do: "s"} remaining
                          <% end %>
                        </p>

                        <form phx-submit="register" class="mt-6 space-y-4">
                          <div>
                            <label
                              for="player_name"
                              class="block text-sm font-medium text-neutral-700 dark:text-neutral-300"
                            >
                              Name <span class="text-danger-600">*</span>
                            </label>
                            <input
                              type="text"
                              name="player_name"
                              id="player_name"
                              required
                              value={@form[:player_name].value}
                              class="mt-1 block w-full rounded-md border-neutral-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm dark:border-secondary-600 dark:bg-secondary-700 dark:text-neutral-100"
                              placeholder="Your full name"
                            />
                          </div>

                          <div>
                            <label
                              for="email"
                              class="block text-sm font-medium text-neutral-700 dark:text-neutral-300"
                            >
                              Email
                              <span class="text-neutral-500 dark:text-neutral-400">(optional)</span>
                            </label>
                            <input
                              type="email"
                              name="email"
                              id="email"
                              value={@form[:email].value}
                              class="mt-1 block w-full rounded-md border-neutral-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm dark:border-secondary-600 dark:bg-secondary-700 dark:text-neutral-100"
                              placeholder="your.email@example.com"
                            />
                          </div>

                          <div>
                            <label
                              for="phone"
                              class="block text-sm font-medium text-neutral-700 dark:text-neutral-300"
                            >
                              Phone
                              <span class="text-neutral-500 dark:text-neutral-400">(optional)</span>
                            </label>
                            <input
                              type="tel"
                              name="phone"
                              id="phone"
                              value={@form[:phone].value}
                              class="mt-1 block w-full rounded-md border-neutral-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm dark:border-secondary-600 dark:bg-secondary-700 dark:text-neutral-100"
                              placeholder="(555) 123-4567"
                            />
                          </div>

                          <button
                            type="submit"
                            class="w-full rounded-md bg-primary-500 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-primary-600 hover:shadow-sporty focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary-600 transition-all duration-200"
                          >
                            <%= if @capacity_info.is_full do %>
                              Join Waitlist
                            <% else %>
                              Register Now
                            <% end %>
                          </button>
                        </form>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
