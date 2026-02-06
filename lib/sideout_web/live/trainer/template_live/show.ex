defmodule SideoutWeb.Trainer.TemplateLive.Show do
  use SideoutWeb, :live_view

  alias Sideout.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    template = Scheduling.get_session_template!(id, preload: [:user])

    {:noreply,
     socket
     |> assign(:page_title, "Template Details")
     |> assign(:template, template)}
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
      <div class="mx-auto max-w-3xl">
        <!-- Header -->
        <div class="mb-6">
          <.link navigate={~p"/trainer/templates"} class="text-sm text-indigo-600 hover:text-indigo-500">
            ← Back to Templates
          </.link>
        </div>

        <div class="overflow-hidden bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-base font-semibold leading-6 text-gray-900">
                  <%= @template.name %>
                </h3>
                <p class="mt-1 max-w-2xl text-sm text-gray-500">Template details and configuration</p>
              </div>
              <div class="flex gap-2">
                <.link
                  navigate={~p"/trainer/templates/#{@template.id}/edit"}
                  class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                >
                  Edit
                </.link>
              </div>
            </div>
          </div>
          <div class="border-t border-gray-200">
            <dl class="divide-y divide-gray-200">
              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Status</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                  <%= if @template.active do %>
                    <span class="inline-flex items-center rounded-full bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
                      Active
                    </span>
                  <% else %>
                    <span class="inline-flex items-center rounded-full bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">
                      Inactive
                    </span>
                  <% end %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Day of Week</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                  <%= format_day(@template.day_of_week) %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Time</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                  <%= format_time(@template.start_time) %> - <%= format_time(@template.end_time) %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Skill Level</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                  <%= format_skill_level(@template.skill_level) %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Fields Available</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                  <%= @template.fields_available %>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Capacity Constraints</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                  <code class="rounded bg-gray-100 px-2 py-1"><%= @template.capacity_constraints %></code>
                </dd>
              </div>

              <div class="px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Cancellation Deadline</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                  <%= @template.cancellation_deadline_hours %> hours before session
                </dd>
              </div>
            </dl>
          </div>
        </div>

        <!-- Actions -->
        <div class="mt-6 flex gap-3">
          <.link
            navigate={~p"/trainer/sessions/new?template_id=#{@template.id}"}
            class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
          >
            Create Session from Template
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
