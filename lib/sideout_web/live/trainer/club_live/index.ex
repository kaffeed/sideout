defmodule SideoutWeb.Trainer.ClubLive.Index do
  use SideoutWeb, :live_view

  alias Sideout.Clubs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_clubs(socket)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Clubs")
    |> assign(:club, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Club")
    |> assign(:club, %Clubs.Club{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    club = Clubs.get_club!(id)

    socket
    |> assign(:page_title, "Edit Club")
    |> assign(:club, club)
  end

  @impl true
  def handle_event("request_membership", %{"club_id" => club_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Clubs.request_membership(user_id, String.to_integer(club_id)) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Membership request sent successfully")
         |> load_clubs()}

      {:error, changeset} ->
        error_message =
          case changeset.errors[:user_id] do
            {msg, _} -> msg
            _ -> "Failed to request membership"
          end

        {:noreply,
         socket
         |> put_flash(:error, error_message)
         |> load_clubs()}
    end
  end

  @impl true
  def handle_info({SideoutWeb.Trainer.ClubLive.FormComponent, {:saved, _club}}, socket) do
    {:noreply, load_clubs(socket)}
  end

  defp load_clubs(socket) do
    user_id = socket.assigns.current_user.id
    user_clubs = Clubs.list_clubs_for_user(user_id)
    all_clubs = Clubs.list_clubs()

    # Filter out clubs the user is already a member of or has pending request
    user_club_ids = Enum.map(user_clubs, & &1.club_id)
    
    available_clubs =
      all_clubs
      |> Enum.reject(fn club -> club.id in user_club_ids end)
      |> Enum.map(fn club ->
        membership = Clubs.get_membership(user_id, club.id)
        Map.put(club, :membership_status, membership && membership.status)
      end)

    socket
    |> assign(:user_clubs, user_clubs)
    |> assign(:available_clubs, available_clubs)
  end

  defp membership_status_badge(status) when is_binary(status) do
    case status do
      "pending" -> "bg-warning-100 dark:bg-warning-900/30 text-warning-800 dark:text-warning-400 border-warning-200"
      "rejected" -> "bg-danger-100 dark:bg-danger-900/30 text-danger-800 dark:text-danger-400 border-danger-200"
      _ -> "bg-neutral-100 dark:bg-secondary-700 text-neutral-800 dark:text-neutral-100 border-neutral-200 dark:border-secondary-600"
    end
  end

  defp membership_status_badge(status) when is_atom(status) do
    case status do
      :pending -> "bg-warning-100 dark:bg-warning-900/30 text-warning-800 dark:text-warning-400 border-warning-200"
      :rejected -> "bg-danger-100 dark:bg-danger-900/30 text-danger-800 dark:text-danger-400 border-danger-200"
      _ -> "bg-neutral-100 dark:bg-secondary-700 text-neutral-800 dark:text-neutral-100 border-neutral-200 dark:border-secondary-600"
    end
  end

  defp role_badge_class(role) when is_binary(role) do
    case role do
      "admin" -> "bg-purple-100 text-purple-800 border-purple-200 dark:bg-purple-900/30 dark:text-purple-400 dark:border-purple-700"
      "trainer" -> "bg-info-100 dark:bg-info-900/30 text-info-600 dark:text-info-400 border-info-200 dark:border-info-700"
      _ -> "bg-neutral-100 dark:bg-secondary-700 text-neutral-800 dark:text-neutral-100 border-neutral-200 dark:border-secondary-600"
    end
  end

  defp role_badge_class(role) when is_atom(role) do
    case role do
      :admin -> "bg-purple-100 text-purple-800 border-purple-200 dark:bg-purple-900/30 dark:text-purple-400 dark:border-purple-700"
      :trainer -> "bg-info-100 dark:bg-info-900/30 text-info-600 dark:text-info-400 border-info-200 dark:border-info-700"
      _ -> "bg-neutral-100 dark:bg-secondary-700 text-neutral-800 dark:text-neutral-100 border-neutral-200 dark:border-secondary-600"
    end
  end

  defp role_text(role) when is_binary(role), do: String.capitalize(role)
  defp role_text(role) when is_atom(role), do: role |> Atom.to_string() |> String.capitalize()

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <!-- Header -->
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-neutral-900 dark:text-neutral-100">Clubs</h1>
            <p class="mt-2 text-sm text-neutral-600 dark:text-neutral-400">
              Manage your club memberships and browse available clubs
            </p>
          </div>
          <.link
            patch={~p"/trainer/clubs/new"}
            class="inline-flex items-center rounded-md bg-primary-500 dark:bg-primary-600 px-3 py-2 text-sm font-semibold text-white shadow-md hover:shadow-sporty hover:bg-primary-600 dark:hover:bg-primary-500 transition-all duration-200"
          >
            Create Club
          </.link>
        </div>

        <!-- My Clubs -->
        <div class="mb-8">
          <h2 class="mb-4 text-lg font-semibold text-neutral-900 dark:text-neutral-100">My Clubs</h2>

          <%= if @user_clubs == [] do %>
            <div class="rounded-lg border-2 border-dashed border-neutral-300 dark:border-secondary-600 bg-white dark:bg-secondary-800 px-4 py-8 text-center">
              <p class="text-sm text-neutral-500 dark:text-neutral-400">
                You are not a member of any clubs yet.
              </p>
              <p class="mt-2 text-sm text-neutral-500 dark:text-neutral-400">
                Create a new club or request to join an existing one below.
              </p>
            </div>
          <% else %>
            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <%= for membership <- @user_clubs do %>
                <.link
                  navigate={~p"/trainer/clubs/#{membership.club_id}"}
                  class="block overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500 hover:shadow-sporty-lg transition-all duration-200"
                >
                  <div class="p-6">
                    <div class="flex items-start justify-between">
                      <h3 class="text-lg font-semibold text-neutral-900 dark:text-neutral-100">
                        <%= membership.club.name %>
                      </h3>
                      <span class={[
                        "inline-flex rounded-full border px-2 py-1 text-xs font-semibold",
                        role_badge_class(membership.role)
                      ]}>
                        <%= role_text(membership.role) %>
                      </span>
                    </div>
                    <%= if membership.club.description do %>
                      <p class="mt-2 text-sm text-neutral-600 dark:text-neutral-400 line-clamp-2">
                        <%= membership.club.description %>
                      </p>
                    <% end %>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Available Clubs -->
        <div>
          <h2 class="mb-4 text-lg font-semibold text-neutral-900 dark:text-neutral-100">
            Browse Clubs
          </h2>

          <%= if @available_clubs == [] do %>
            <div class="rounded-lg border-2 border-dashed border-neutral-300 dark:border-secondary-600 bg-white dark:bg-secondary-800 px-4 py-8 text-center">
              <p class="text-sm text-neutral-500 dark:text-neutral-400">
                No other clubs available at the moment.
              </p>
            </div>
          <% else %>
            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <%= for club <- @available_clubs do %>
                <div class="overflow-hidden rounded-lg bg-white dark:bg-secondary-800 shadow-sporty border-t-4 border-primary-500">
                  <div class="p-6">
                    <h3 class="text-lg font-semibold text-neutral-900 dark:text-neutral-100">
                      <%= club.name %>
                    </h3>
                    <%= if club.description do %>
                      <p class="mt-2 text-sm text-neutral-600 dark:text-neutral-400 line-clamp-3">
                        <%= club.description %>
                      </p>
                    <% end %>
                    <div class="mt-4">
                      <%= if club.membership_status == :pending do %>
                        <span class={[
                          "inline-flex w-full justify-center rounded-md border px-3 py-2 text-sm font-semibold",
                          membership_status_badge(:pending)
                        ]}>
                          Request Pending
                        </span>
                      <% else %>
                        <%= if club.membership_status == :rejected do %>
                          <span class={[
                            "inline-flex w-full justify-center rounded-md border px-3 py-2 text-sm font-semibold",
                            membership_status_badge(:rejected)
                          ]}>
                            Request Rejected
                          </span>
                        <% else %>
                          <button
                            phx-click="request_membership"
                            phx-value-club_id={club.id}
                            class="inline-flex w-full justify-center items-center rounded-md bg-primary-600 dark:bg-primary-500 px-3 py-2 text-sm font-semibold text-white shadow-sporty hover:bg-primary-500 dark:hover:bg-primary-400 transition-all duration-200"
                          >
                            Request to Join
                          </button>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Modal for Create/Edit Club -->
    <.modal
      :if={@live_action in [:new, :edit]}
      id="club-modal"
      show
      on_cancel={JS.patch(~p"/trainer/clubs")}
    >
      <.live_component
        module={SideoutWeb.Trainer.ClubLive.FormComponent}
        id={@club.id || :new}
        title={@page_title}
        action={@live_action}
        club={@club}
        current_user={@current_user}
        patch={~p"/trainer/clubs"}
      />
    </.modal>
    """
  end
end
