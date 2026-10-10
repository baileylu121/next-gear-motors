defmodule NextGearMotors.Vehicles.CoversRetryTest do
  use NextGearMotors.DataCase

  alias NextGearMotors.Vehicles.Covers

  test "transient error then success resolves on attempt 2 with 2 calls" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      n = Agent.get_and_update(counter, &{&1 + 1, &1 + 1})

      if n < 2 do
        {:error, {:http_error, 500, "slow down"}}
      else
        {:ok, "photo.jpg"}
      end
    end

    assert {:ok, "photo.jpg"} =
             Covers.store_with_retries(%{filename: "photo.jpg"}, store_fn: store_fn)

    assert Agent.get(counter, & &1) == 2
  end

  test "sustained transient returns error after exactly 3 calls" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      Agent.update(counter, &(&1 + 1))
      {:error, {:http_error, 503, "unavailable"}}
    end

    assert {:error, {:http_error, 503, "unavailable"}} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0
             )

    assert Agent.get(counter, & &1) == 3
  end

  test "permanent validation error fails after exactly 1 call" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      Agent.update(counter, &(&1 + 1))
      {:error, "extension found on /tmp/x was not contained within [\".png\"]"}
    end

    assert {:error, _} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0
             )

    assert Agent.get(counter, & &1) == 1
  end

  test "permanent image error fails after exactly 1 call" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      Agent.update(counter, &(&1 + 1))
      {:error, [%Image.Error{message: "nope", reason: "Failed to find load"}]}
    end

    assert {:error, _} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0
             )

    assert Agent.get(counter, & &1) == 1
  end

  test "linked child crash is isolated and retried to success" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      n = Agent.get_and_update(counter, &{&1 + 1, &1 + 1})

      if n < 2 do
        spawn_link(fn -> raise "boom" end)
        Process.sleep(:infinity)
      else
        {:ok, "photo.jpg"}
      end
    end

    assert {:ok, "photo.jpg"} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0,
               attempt_timeout_ms: 2_000
             )

    assert Agent.get(counter, & &1) == 2
  end

  test "linked child crash of unknown shape fails after exactly 1 call" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      Agent.update(counter, &(&1 + 1))

      spawn_link(fn -> raise "boom" end)
      Process.sleep(:infinity)
    end

    assert {:error, _} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0,
               attempt_timeout_ms: 2_000,
               transient_crash_patterns: []
             )

    assert Agent.get(counter, & &1) == 1
  end

  test "attempt timeout kills the stuck attempt and retries to success" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      n = Agent.get_and_update(counter, &{&1 + 1, &1 + 1})

      if n < 2 do
        Process.sleep(:infinity)
      else
        {:ok, "photo.jpg"}
      end
    end

    assert {:ok, "photo.jpg"} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0,
               attempt_timeout_ms: 100
             )

    assert Agent.get(counter, & &1) == 2
  end

  test "attempt timeout sustained returns error and cleans up" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)
    test_pid = self()

    store_fn = fn _cover ->
      Agent.update(counter, &(&1 + 1))
      send(test_pid, {:attempt_pid, self()})
      Process.sleep(:infinity)
    end

    assert {:error, :attempt_timeout} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0,
               attempt_timeout_ms: 100
             )

    assert Agent.get(counter, & &1) == 3

    for _ <- 1..3 do
      assert_receive {:attempt_pid, pid}, 1_000
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 2_000
    end
  end

  test "wrapped transient error then success resolves on attempt 2 with 2 calls" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      n = Agent.get_and_update(counter, &{&1 + 1, &1 + 1})

      if n < 2 do
        {:error, [{:http_error, 503, "unavailable"}]}
      else
        {:ok, "photo.jpg"}
      end
    end

    assert {:ok, "photo.jpg"} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0
             )

    assert Agent.get(counter, & &1) == 2
  end

  test "wrapped permanent error fails after exactly 1 call" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      Agent.update(counter, &(&1 + 1))

      {:error,
       [
         %Image.Error{
           message: "open /tmp/x: Failed to find load",
           reason: "Failed to find load"
         }
       ]}
    end

    assert {:error, _} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0
             )

    assert Agent.get(counter, & &1) == 1
  end

  test "mixed wrapped reasons retry when any reason is transient" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    store_fn = fn _cover ->
      Agent.update(counter, &(&1 + 1))

      {:error,
       ["extension found on /tmp/x was not contained within [\".png\"]", {:http_error, 503, "x"}]}
    end

    assert {:error, _} =
             Covers.store_with_retries(%{filename: "photo.jpg"},
               store_fn: store_fn,
               backoff_ms: 0
             )

    assert Agent.get(counter, & &1) == 3
  end
end
