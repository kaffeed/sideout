defmodule SideoutWeb.Trainer.TemplateLive.Index do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling
  alias Sideout.Scheduling.SessionTemplate

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_templates(socket)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Session Templates")
    |> assign(:template, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Session Template")
    |> assign(:template, %SessionTemplate{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    template = Scheduling.get_session_template!(id)

    socket
    |> assign(:page_title, "Edit Session Template")
    |> assign(:template, template)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    template = Scheduling.get_session_template!(id)
    {:ok, _} = Scheduling.delete_session_template(template)

    {:noreply, load_templates(socket)}
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    template = Scheduling.get_session_template!(id)
    {:ok, _} = Scheduling.update_session_template(template, %{active: !template.active})

    {:noreply, load_templates(socket)}
  end

  @impl true
  def handle_info({SideoutWeb.Trainer.TemplateLive.FormComponent, {:saved, _template}}, socket) do
    {:noreply, load_templates(socket)}
  end

  defp load_templates(socket) do
    user = socket.assigns.current_user
    templates = Scheduling.list_session_templates(user.id, preload: [:user])
    assign(socket, :templates, templates)
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end

  defp format_day(day) do
    day |> Atom.to_string() |> String.capitalize()
  end

  defp format_skill_level(level) do
    level |> Atom.to_string() |> String.capitalize()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <!-- Header -->
        <div class="sm:flex sm:items-center sm:justify-between">
          <div>
            <h1 class="text-3xl font-bold text-neutral-900 dark:text-neutral-100">Session Templates</h1>
            <p class="mt-2 text-sm text-neutral-600 dark:text-neutral-400">
              Create templates for recurring sessions to quickly schedule new training sessions.
            </p>
          </div>
          <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
            <.link
              patch={~p"/trainer/templates/new"}
              class="block rounded-md bg-primary-500 px-3 py-2 text-center text-sm font-semibold text-white shadow-md hover:bg-primary-600 hover:shadow-sporty focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary-600 transition-all duration-200"
            >
              Create Template
            </.link>
          </div>
        </div>

        <!-- Templates List -->
        <div class="mt-8">
          <%= if @templates == [] do %>
            <div class="text-center">
              <svg
                class="mx-auto h-12 w-12 text-neutral-400 dark:text-neutral-500"
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
              <h3 class="mt-2 text-sm font-semibold text-neutral-900 dark:text-neutral-100">No templates</h3>
              <p class="mt-1 text-sm text-neutral-600 dark:text-neutral-400">
                Get started by creating a new session template.
              </p>
              <div class="mt-6">
                <.link
                  patch={~p"/trainer/templates/new"}
                  class="inline-flex items-center rounded-md bg-primary-500 px-3 py-2 text-sm font-semibold text-white shadow-md hover:bg-primary-600 hover:shadow-sporty transition-all duration-200"
                >
                  Create Template
                </.link>
              </div>
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
                      Name
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100">
                      Day & Time
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100">
                      Skill Level
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100">
                      Capacity
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-neutral-900 dark:text-neutral-100">
                      Status
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-neutral-200 dark:divide-secondary-700 bg-white dark:bg-secondary-800">
                  <%= for template <- @templates do %>
                    <tr>
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-neutral-900 dark:text-neutral-100 sm:pl-6">
                        <%= template.name %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-neutral-600 dark:text-neutral-400">
                        <%= format_day(template.day_of_week) %><br />
                        <%= format_time(template.start_time) %> - <%= format_time(
                          template.end_time
                        ) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-neutral-600 dark:text-neutral-400">
                        <%= format_skill_level(template.skill_level) %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-neutral-600 dark:text-neutral-400">
                        <%= template.capacity_constraints %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm">
                        <%= if template.active do %>
                          <span class="inline-flex items-center rounded-full bg-success-50 px-2 py-1 text-xs font-medium text-success-700 ring-1 ring-inset ring-success-600/20 dark:bg-success-900/30 dark:text-success-400 dark:ring-success-400/30">
                            Active
                          </span>
                        <% else %>
                          <span class="inline-flex items-center rounded-full bg-neutral-100 px-2 py-1 text-xs font-medium text-neutral-600 ring-1 ring-inset ring-neutral-500/10 dark:bg-secondary-700 dark:text-neutral-400 dark:ring-neutral-400/20">
                            Inactive
                          </span>
                        <% end %>
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <div class="flex justify-end gap-2">
                          <.link
                            navigate={~p"/trainer/templates/#{template.id}"}
                            class="text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
                          >
                            View
                          </.link>
                          <.link
                            patch={~p"/trainer/templates/#{template.id}/edit"}
                            class="text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
                          >
                            Edit
                          </.link>
                          <button
                            type="button"
                            phx-click="toggle_active"
                            phx-value-id={template.id}
                            class="text-warning-600 hover:text-warning-500 dark:text-warning-400 dark:hover:text-warning-300 transition-colors"
                          >
                            <%= if template.active, do: "Deactivate", else: "Activate" %>
                          </button>
                          <.link
                            phx-click="delete"
                            phx-value-id={template.id}
                            data-confirm="Are you sure you want to delete this template?"
                            class="text-danger-600 hover:text-danger-500 dark:text-danger-400 dark:hover:text-danger-300 transition-colors"
                          >
                            Delete
                          </.link>
                        </div>
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

    <.modal
      :if={@live_action in [:new, :edit]}
      id="template-modal"
      show
      on_cancel={JS.patch(~p"/trainer/templates")}
    >
      <.live_component
        module={SideoutWeb.Trainer.TemplateLive.FormComponent}
        id={@template.id || :new}
        title={@page_title}
        action={@live_action}
        template={@template}
        current_user={@current_user}
        patch={~p"/trainer/templates"}
      />
    </.modal>
    """
  end
end
