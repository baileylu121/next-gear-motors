defmodule NextGearMotors.Vehicles.Covers do
  @moduledoc """
  The Vehicles Covers context.
  """

  import Ecto.Query, warn: false
  alias NextGearMotors.Repo

  alias NextGearMotors.Vehicles.Covers.Cover

  @doc """
  Returns the list of covers.

  ## Examples

      iex> list_covers()
      [%Cover{}, ...]

  """
  def list_covers do
    Repo.all(Cover)
  end

  @max_store_attempts 3
  @store_attempt_timeout_ms 120_000

  def store_with_retries(cover, opts \\ []) do
    store_fn = Keyword.get(opts, :store_fn, &Cover.store/1)
    backoff_ms = Keyword.get(opts, :backoff_ms, 1_000)
    attempt_timeout_ms = Keyword.get(opts, :attempt_timeout_ms, @store_attempt_timeout_ms)
    on_retry = Keyword.get(opts, :on_retry, fn _attempt -> :ok end)

    transient_crash_patterns =
      Keyword.get(opts, :transient_crash_patterns, [RuntimeError, ErlangError, ExAws.Error])

    run_store_attempt(cover, store_fn, @max_store_attempts, 1,
      backoff_ms: backoff_ms,
      attempt_timeout_ms: attempt_timeout_ms,
      transient_crash_patterns: transient_crash_patterns,
      on_retry: on_retry
    )
  end

  defp run_store_attempt(cover, store_fn, attempts_left, attempt, opts) do
    case isolated_store_call(store_fn, cover, opts[:attempt_timeout_ms]) do
      {:ok, _} = ok ->
        ok

      {:error, reason} = error ->
        if attempts_left > 1 and transient_store_failure?(reason, opts[:transient_crash_patterns]) do
          require Logger

          Logger.warning(
            "cover store failed, retrying attempt=#{attempt}/#{@max_store_attempts} reason=#{inspect(reason)}"
          )

          opts[:on_retry].(attempt + 1)
          backoff_sleep(opts[:backoff_ms], attempt)
          run_store_attempt(cover, store_fn, attempts_left - 1, attempt + 1, opts)
        else
          error
        end
    end
  end

  defp isolated_store_call(store_fn, cover, attempt_timeout_ms) do
    caller = self()
    ref = make_ref()

    {:ok, pid} =
      Task.Supervisor.start_child(NextGearMotors.TaskSupervisor, fn ->
        send(caller, {ref, run_store_fn(store_fn, cover)})
      end)

    monitor = Process.monitor(pid)

    receive do
      {^ref, result} ->
        Process.demonitor(monitor, [:flush])
        result

      {:DOWN, ^monitor, :process, ^pid, :normal} ->
        {:error, :attempt_no_result}

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        {:error, {:linked_crash, reason}}
    after
      attempt_timeout_ms ->
        Process.demonitor(monitor, [:flush])
        Task.Supervisor.terminate_child(NextGearMotors.TaskSupervisor, pid)
        {:error, :attempt_timeout}
    end
  end

  defp run_store_fn(store_fn, cover) do
    try do
      store_fn.(cover)
    rescue
      e -> {:error, e}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp transient_store_failure?({:http_error, status, _}, _patterns)
       when status in [429] or (status >= 500 and status < 600),
       do: true

  defp transient_store_failure?(%ExAws.Error{}, _patterns), do: true

  defp transient_store_failure?({:error, %ExAws.Error{}}, _patterns), do: true

  defp transient_store_failure?({:socket_error, _}, _patterns), do: true

  defp transient_store_failure?({:conn_failed, _}, _patterns), do: true

  defp transient_store_failure?(:timeout, _patterns), do: true

  defp transient_store_failure?(:attempt_timeout, _patterns), do: true

  defp transient_store_failure?({:linked_crash, {%mod{}, _}}, patterns)
       when is_list(patterns) do
    mod in patterns
  end

  defp transient_store_failure?({:linked_crash, {nodereason, _}}, _patterns)
       when nodereason in [:timeout, :killed],
       do: true

  defp transient_store_failure?({:exited, _}, _patterns), do: true

  defp transient_store_failure?(reasons, patterns) when is_list(reasons) do
    Enum.any?(reasons, &transient_store_failure?(&1, patterns))
  end

  defp transient_store_failure?(_reason, _patterns), do: false

  defp backoff_sleep(0, _attempt), do: :ok

  defp backoff_sleep(base_ms, attempt) do
    Process.sleep(trunc(base_ms * :math.pow(2, attempt - 1) * (0.5 + :rand.uniform())))
  end
end
