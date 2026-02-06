defmodule SideoutWeb.Trainer.ClubLive.FormComponent do
  use SideoutWeb, :live_component

  alias Sideout.Clubs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>
          <%= if @action == :new do %>
            Create a new club to organize your training sessions and manage your team.
          <% else %>
            Update your club information and settings.
          <% end %>
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="club-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:name]}
          type="text"
          label="Club Name"
          placeholder="e.g., Beach Volleyball Munich"
          required
        />

        <.input
          field={@form[:description]}
          type="textarea"
          label="Description"
          placeholder="Tell people about your club, training style, location, etc."
          rows="4"
        />

        <:actions>
          <.button phx-disable-with="Saving...">
            {if @action == :new, do: "Create Club", else: "Save Changes"}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{club: club} = assigns, socket) do
    changeset = Clubs.Club.changeset(club, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"club" => club_params}, socket) do
    changeset =
      socket.assigns.club
      |> Clubs.Club.changeset(club_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"club" => club_params}, socket) do
    save_club(socket, socket.assigns.action, club_params)
  end

  defp save_club(socket, :edit, club_params) do
    case Clubs.update_club(socket.assigns.club, club_params) do
      {:ok, club} ->
        notify_parent({:saved, club})

        {:noreply,
         socket
         |> put_flash(:info, "Club updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_club(socket, :new, club_params) do
    user_id = socket.assigns.current_user.id

    case Clubs.create_club(user_id, club_params) do
      {:ok, club} ->
        notify_parent({:saved, club})

        {:noreply,
         socket
         |> put_flash(:info, "Club created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
