defmodule Sideout.Scheduling.Session do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sideout.Accounts.User
  alias Sideout.Scheduling.{SessionTemplate, Registration, ConstraintResolver}

  schema "sessions" do
    field :status, Ecto.Enum,
      values: [:scheduled, :in_progress, :completed, :cancelled],
      default: :scheduled

    field :date, :date
    field :start_time, :time
    field :end_time, :time
    field :fields_available, :integer, default: 1
    field :capacity_constraints, :string
    field :cancellation_deadline_hours, :integer, default: 24
    field :notes, :string
    field :share_token, :string

    # Virtual field for parsed constraints (list of individual specs)
    field :constraint_list, {:array, :any}, virtual: true

    # Virtual field for composed specification (single spec using AND composition)
    # Can be set programmatically for complex OR/NOT logic
    field :capacity_spec, :any, virtual: true

    belongs_to :session_template, SessionTemplate
    belongs_to :user, User
    belongs_to :club, Sideout.Clubs.Club
    has_many :registrations, Registration
    has_many :guest_clubs, Sideout.Scheduling.SessionGuestClub
    has_many :invited_clubs, through: [:guest_clubs, :club]
    has_many :session_cotrainers, Sideout.Scheduling.SessionCotrainer
    has_many :cotrainers, through: [:session_cotrainers, :user]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :date,
      :start_time,
      :end_time,
      :fields_available,
      :capacity_constraints,
      :cancellation_deadline_hours,
      :notes,
      :status,
      :session_template_id,
      :user_id,
      :share_token,
      :club_id
    ])
    |> validate_required([:date, :start_time, :end_time, :capacity_constraints, :club_id])
    |> validate_number(:fields_available, greater_than: 0)
    |> validate_number(:cancellation_deadline_hours, greater_than_or_equal_to: 0)
    |> validate_time_order()
    |> validate_future_date()
    |> validate_constraint_format()
    |> unique_constraint(:share_token)
  end

  defp validate_time_order(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && Time.compare(start_time, end_time) != :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end

  defp validate_future_date(changeset) do
    # Skip validation for completed or cancelled sessions
    status = get_field(changeset, :status)

    if status in [:completed, :cancelled] do
      changeset
    else
      case get_change(changeset, :date) do
        nil ->
          changeset

        date ->
          if Date.compare(date, Date.utc_today()) == :lt do
            add_error(changeset, :date, "must be today or in the future")
          else
            changeset
          end
      end
    end
  end

  defp validate_constraint_format(changeset) do
    case get_change(changeset, :capacity_constraints) do
      nil ->
        changeset

      "" ->
        add_error(changeset, :capacity_constraints, "cannot be empty")

      constraints ->
        if String.match?(constraints, ~r/^[a-z_0-9]+(,[a-z_0-9]+)*$/) do
          changeset
        else
          add_error(changeset, :capacity_constraints, "must be comma-separated constraint names")
        end
    end
  end

  @doc """
  Returns session with parsed constraint list in virtual field.

  ## Examples

      iex> session = get_session!(1)
      iex> session |> Session.with_parsed_constraints()
      %Session{constraint_list: [%MaxCapacityConstraint{...}, ...]}

  """
  def with_parsed_constraints(%__MODULE__{} = session) do
    constraints =
      ConstraintResolver.parse_constraints(
        session.capacity_constraints,
        session.fields_available
      )

    %{session | constraint_list: constraints}
  end

  @doc """
  Returns session with composed specification in virtual field.

  The composed specification combines all constraints using AND logic.
  For custom composition (OR/NOT), set the capacity_spec field directly.

  ## Examples

      iex> session = get_session!(1)
      iex> session |> Session.with_capacity_spec()
      %Session{capacity_spec: %AndSpecification{...}}

      # Custom composition
      iex> custom_spec = Specification.or_spec(max_18, per_field_9)
      iex> %{session | capacity_spec: custom_spec}

  """
  def with_capacity_spec(%__MODULE__{capacity_spec: spec} = session) when not is_nil(spec) do
    # If capacity_spec is already set (programmatic composition), return as-is
    session
  end

  def with_capacity_spec(%__MODULE__{} = session) do
    # Parse from string and compose with AND
    spec =
      ConstraintResolver.parse_to_specification(
        session.capacity_constraints,
        session.fields_available
      )

    %{session | capacity_spec: spec}
  end
end
