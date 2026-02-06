defmodule SideoutWeb.Trainer.ClubLive.Show do
  use SideoutWeb, :live_view

  alias Sideout.Clubs
  alias Sideout.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    club = Clubs.get_club_with_members(String.to_integer(id))
    user = socket.assigns.current_user

    # Check if user is a member
    unless Clubs.is_club_member?(user.id, club.id) do
      {:noreply,
       socket
       |> put_flash(:error, "You do not have access to this club")
       |> push_navigate(to: ~p"/trainer/clubs")}
    else
      is_admin = Clubs.is_club_admin?(user.id, club.id)

      members = Clubs.list_members(club.id)
      pending_requests = if is_admin, do: Clubs.list_pending_requests(club.id), else: []

      # Load recent sessions for this club
      sessions = Scheduling.list_sessions_for_club(club.id, limit: 10)

      {:noreply,
       socket
       |> assign(:page_title, club.name)
       |> assign(:club, club)
       |> assign(:is_admin, is_admin)
       |> assign(:members, members)
       |> assign(:pending_requests, pending_requests)
       |> assign(:sessions, sessions)
       |> assign(:show_leave_modal, false)}
    end
  end

  @impl true
  def handle_event("approve_membership", %{"membership_id" => membership_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Clubs.approve_membership(String.to_integer(membership_id), user_id) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Membership approved successfully")
         |> reload_club()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to approve membership")
         |> reload_club()}
    end
  end

  def handle_event("reject_membership", %{"membership_id" => membership_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Clubs.reject_membership(String.to_integer(membership_id), user_id) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Membership rejected")
         |> reload_club()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to reject membership")
         |> reload_club()}
    end
  end

  def handle_event("promote_to_admin", %{"user_id" => user_id}, socket) do
    club_id = socket.assigns.club.id

    case Clubs.promote_to_admin(club_id, String.to_integer(user_id)) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "User promoted to admin")
         |> reload_club()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to promote user")
         |> reload_club()}
    end
  end

  def handle_event("demote_to_trainer", %{"user_id" => user_id}, socket) do
    club_id = socket.assigns.club.id

    case Clubs.demote_to_trainer(club_id, String.to_integer(user_id)) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "User demoted to trainer")
         |> reload_club()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to demote user")
         |> reload_club()}
    end
  end

  def handle_event("remove_member", %{"user_id" => user_id}, socket) do
    club_id = socket.assigns.club.id

    case Clubs.remove_member(club_id, String.to_integer(user_id)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Member removed successfully")
         |> reload_club()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to remove member")
         |> reload_club()}
    end
  end

  def handle_event("show_leave_modal", _params, socket) do
    {:noreply, assign(socket, :show_leave_modal, true)}
  end

  def handle_event("close_leave_modal", _params, socket) do
    {:noreply, assign(socket, :show_leave_modal, false)}
  end

  def handle_event("confirm_leave", _params, socket) do
    club_id = socket.assigns.club.id
    user_id = socket.assigns.current_user.id

    case Clubs.remove_member(club_id, user_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "You have left the club")
         |> push_navigate(to: ~p"/trainer/clubs")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to leave club")
         |> assign(:show_leave_modal, false)}
    end
  end

  defp reload_club(socket) do
    club = Clubs.get_club_with_members(socket.assigns.club.id)
    members = Clubs.list_members(club.id)

    pending_requests =
      if socket.assigns.is_admin, do: Clubs.list_pending_requests(club.id), else: []

    socket
    |> assign(:club, club)
    |> assign(:members, members)
    |> assign(:pending_requests, pending_requests)
  end

  defp role_badge_class(role) when is_binary(role) do
    case role do
      "admin" ->
        "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400 border-purple-200 dark:border-purple-700"

      "trainer" ->
        "bg-info-100 text-info-800 dark:bg-info-900/30 dark:text-info-400 border-info-200 dark:border-info-700"

      _ ->
        "bg-neutral-100 text-neutral-800 dark:bg-secondary-700 dark:text-neutral-100 border-neutral-200 dark:border-secondary-700"
    end
  end

  defp role_badge_class(role) when is_atom(role) do
    case role do
      :admin ->
        "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400 border-purple-200 dark:border-purple-700"

      :trainer ->
        "bg-info-100 text-info-800 dark:bg-info-900/30 dark:text-info-400 border-info-200 dark:border-info-700"

      _ ->
        "bg-neutral-100 text-neutral-800 dark:bg-secondary-700 dark:text-neutral-100 border-neutral-200 dark:border-secondary-700"
    end
  end

  defp role_text(role) when is_binary(role), do: String.capitalize(role)
  defp role_text(role) when is_atom(role), do: role |> Atom.to_string() |> String.capitalize()

  defp format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-5xl">
        <!-- Back Button -->
        <div class="mb-6">
          <.link
            navigate={~p"/trainer/clubs"}
            class="inline-flex items-center text-sm font-medium text-primary-600 dark:text-primary-400 hover:text-primary-500 dark:hover:text-primary-300 transition-colors"
          >
            <svg class="mr-2 h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 19l-7-7 7-7"
              />
            </svg>
            Back to Clubs
          </.link>
        </div>
        
    <!-- Club Header -->
        <div class="mb-8 overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500">
          <div class="px-6 py-5">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h1 class="text-2xl font-bold text-neutral-900 dark:text-neutral-100">
                  {@club.name}
                </h1>
                <%= if @club.description do %>
                  <p class="mt-2 text-sm text-neutral-600 dark:text-neutral-400">
                    {@club.description}
                  </p>
                <% end %>
              </div>
            </div>
            
    <!-- Action Buttons -->
            <div class="mt-6 flex flex-wrap gap-3">
              <%= if @is_admin do %>
                <.link
                  patch={~p"/trainer/clubs/#{@club.id}/edit"}
                  class="inline-flex items-center rounded-md bg-white dark:bg-secondary-700 px-3 py-2 text-sm font-semibold text-neutral-900 dark:text-neutral-100 shadow-sm ring-1 ring-inset ring-neutral-300 dark:ring-secondary-600 hover:bg-neutral-50 dark:hover:bg-secondary-600 transition-colors"
                >
                  Edit Club
                </.link>
              <% end %>

              <button
                phx-click="show_leave_modal"
                class="inline-flex items-center rounded-md bg-danger-600 dark:bg-danger-500 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-danger-500 dark:hover:bg-danger-400 transition-colors"
              >
                Leave Club
              </button>
            </div>
          </div>
        </div>
        
    <!-- Pending Requests (Admin Only) -->
        <%= if @is_admin and @pending_requests != [] do %>
          <div class="mb-8">
            <h2 class="mb-4 text-lg font-semibold text-neutral-900 dark:text-neutral-100">
              Pending Membership Requests
            </h2>
            <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-warning-500">
              <ul role="list" class="divide-y divide-neutral-200 dark:divide-secondary-700">
                <%= for request <- @pending_requests do %>
                  <li class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <p class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                          {request.user.email}
                        </p>
                        <p class="text-xs text-neutral-500 dark:text-neutral-400">
                          Requested {Calendar.strftime(request.inserted_at, "%b %-d, %Y")}
                        </p>
                      </div>
                      <div class="flex gap-2">
                        <button
                          phx-click="approve_membership"
                          phx-value-membership_id={request.id}
                          class="inline-flex items-center rounded-md bg-success-600 dark:bg-success-500 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-success-500 dark:hover:bg-success-400 transition-colors"
                        >
                          Approve
                        </button>
                        <button
                          phx-click="reject_membership"
                          phx-value-membership_id={request.id}
                          class="inline-flex items-center rounded-md bg-danger-600 dark:bg-danger-500 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-danger-500 dark:hover:bg-danger-400 transition-colors"
                        >
                          Reject
                        </button>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        <% end %>
        
    <!-- Members -->
        <div class="mb-8">
          <h2 class="mb-4 text-lg font-semibold text-neutral-900 dark:text-neutral-100">
            Members ({length(@members)})
          </h2>
          <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500">
            <ul role="list" class="divide-y divide-neutral-200 dark:divide-secondary-700">
              <%= for member <- @members do %>
                <li class="px-6 py-4">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-3 flex-1">
                      <div class="flex-1">
                        <p class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                          {member.user.email}
                        </p>
                      </div>
                      <span class={[
                        "inline-flex rounded-full border px-2 py-1 text-xs font-semibold",
                        role_badge_class(member.role)
                      ]}>
                        {role_text(member.role)}
                      </span>
                    </div>
                    <%= if @is_admin and member.user_id != @current_user.id do %>
                      <div class="flex gap-2 ml-4">
                        <%= if member.role == "trainer" do %>
                          <button
                            phx-click="promote_to_admin"
                            phx-value-user_id={member.user_id}
                            class="text-sm text-primary-600 dark:text-primary-400 hover:text-primary-500 dark:hover:text-primary-300 transition-colors"
                          >
                            Promote
                          </button>
                        <% else %>
                          <button
                            phx-click="demote_to_trainer"
                            phx-value-user_id={member.user_id}
                            class="text-sm text-primary-600 dark:text-primary-400 hover:text-primary-500 dark:hover:text-primary-300 transition-colors"
                          >
                            Demote
                          </button>
                        <% end %>
                        <button
                          phx-click="remove_member"
                          phx-value-user_id={member.user_id}
                          class="text-sm text-danger-600 dark:text-danger-400 hover:text-danger-500 dark:hover:text-danger-300 transition-colors"
                        >
                          Remove
                        </button>
                      </div>
                    <% end %>
                  </div>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
        
    <!-- Recent Sessions -->
        <div>
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-neutral-900 dark:text-neutral-100">
              Recent Sessions
            </h2>
            <.link
              navigate={~p"/trainer/sessions"}
              class="text-sm text-primary-600 dark:text-primary-400 hover:text-primary-500 dark:hover:text-primary-300 transition-colors"
            >
              View all sessions →
            </.link>
          </div>

          <%= if @sessions == [] do %>
            <div class="rounded-lg border-2 border-dashed border-neutral-300 dark:border-secondary-600 bg-white dark:bg-secondary-800 px-4 py-8 text-center">
              <p class="text-sm text-neutral-500 dark:text-neutral-400">No sessions yet</p>
              <.link
                navigate={~p"/trainer/sessions/new"}
                class="mt-2 text-sm text-primary-600 dark:text-primary-400 hover:text-primary-500 dark:hover:text-primary-300 transition-colors"
              >
                Create your first session →
              </.link>
            </div>
          <% else %>
            <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500">
              <ul role="list" class="divide-y divide-neutral-200 dark:divide-secondary-700">
                <%= for session <- @sessions do %>
                  <li>
                    <.link
                      navigate={~p"/trainer/sessions/#{session.id}"}
                      class="block px-6 py-4 hover:bg-neutral-50 dark:hover:bg-secondary-700 transition-colors"
                    >
                      <div class="flex items-center justify-between">
                        <div>
                          <p class="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                            {format_date(session.date)}
                          </p>
                          <p class="text-sm text-neutral-500 dark:text-neutral-400">
                            {format_time(session.start_time)} - {format_time(session.end_time)}
                          </p>
                        </div>
                        <div class="text-sm text-neutral-500 dark:text-neutral-400">
                          {Scheduling.get_capacity_status(session).description}
                        </div>
                      </div>
                    </.link>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Leave Club Modal -->
    <%= if @show_leave_modal do %>
      <div class="relative z-50" role="dialog" aria-modal="true">
        <div class="fixed inset-0 bg-neutral-500 dark:bg-neutral-900 bg-opacity-75 dark:bg-opacity-75 transition-opacity">
        </div>
        <div class="fixed inset-0 z-10 overflow-y-auto">
          <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
            <div class="relative transform overflow-hidden rounded-lg bg-white dark:bg-secondary-800 px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
              <div class="sm:flex sm:items-start">
                <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-danger-100 dark:bg-danger-900/30 sm:mx-0 sm:h-10 sm:w-10">
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
                    Leave Club
                  </h3>
                  <div class="mt-2">
                    <p class="text-sm text-neutral-500 dark:text-neutral-400">
                      Are you sure you want to leave this club? You will need to request membership again to rejoin.
                    </p>
                  </div>
                  <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                    <button
                      phx-click="confirm_leave"
                      class="inline-flex w-full justify-center rounded-md bg-danger-600 dark:bg-danger-500 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-danger-500 dark:hover:bg-danger-400 transition-colors sm:ml-3 sm:w-auto"
                    >
                      Leave Club
                    </button>
                    <button
                      phx-click="close_leave_modal"
                      class="mt-3 inline-flex w-full justify-center rounded-md bg-white dark:bg-secondary-700 px-3 py-2 text-sm font-semibold text-neutral-900 dark:text-neutral-100 shadow-sm ring-1 ring-inset ring-neutral-300 dark:ring-secondary-600 hover:bg-neutral-50 dark:hover:bg-secondary-600 transition-colors sm:mt-0 sm:w-auto"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <!-- Modal for Edit Club -->
    <.modal
      :if={@live_action == :edit}
      id="club-modal"
      show
      on_cancel={JS.patch(~p"/trainer/clubs/#{@club.id}")}
    >
      <.live_component
        module={SideoutWeb.Trainer.ClubLive.FormComponent}
        id={@club.id}
        title="Edit Club"
        action={:edit}
        club={@club}
        current_user={@current_user}
        patch={~p"/trainer/clubs/#{@club.id}"}
      />
    </.modal>
    """
  end
end
