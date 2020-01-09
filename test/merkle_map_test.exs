defmodule MerkleMapTest do
  use ExUnit.Case
  doctest MerkleMap

  describe "MerkleMap.new/2" do
    test "transforms map" do
      mm = MerkleMap.new(1..10, fn x -> {x, x * x} end) |> MerkleMap.update_hashes()
      mm2 = Map.new(1..10, fn x -> {x, x * x} end) |> MerkleMap.new() |> MerkleMap.update_hashes()
      assert MerkleMap.equal?(mm, mm2)
    end
  end

  describe "MerkleMap.delete/2" do
    test "deletes a record" do
      mm =
        MerkleMap.new(%{"foo" => "bar"})
        |> MerkleMap.delete("foo")

      refute MerkleMap.has_key?(mm, "foo")
    end
  end

  describe "MerkleMap.diff_keys/3" do
    test "diffs keys" do
      mm1 = MerkleMap.new(%{"foo" => "bar"}) |> MerkleMap.update_hashes()
      mm2 = MerkleMap.new(%{"foo" => "baz"}) |> MerkleMap.update_hashes()
      assert {:ok, ["foo"]} = MerkleMap.diff_keys(mm1, mm2)
    end

    def do_partial_diffs({mm1, mm2}) do
      {:continue, partial_diff} = MerkleMap.prepare_partial_diff(mm1, 8)
      do_partial_diffs(partial_diff, {mm2, mm1})
    end

    def do_partial_diffs(partial_diff, {mm1, mm2}) do
      case MerkleMap.continue_partial_diff(partial_diff, mm1, 8) do
        {:continue, partial_diff} ->
          do_partial_diffs(partial_diff, {mm2, mm1})

        {:ok, diffs} ->
          {:ok, diffs}
      end
    end

    test "can do diff in steps (save transmitting data) (small example)" do
      mm1 = MerkleMap.new([1], fn x -> {x, x} end) |> MerkleMap.update_hashes()

      mm2 = MerkleMap.new([], fn x -> {x, x} end) |> MerkleMap.update_hashes()

      assert {:ok, keys} = MerkleMap.diff_keys(mm1, mm2)
      assert [1] == keys

      assert {:ok, diff_keys} = do_partial_diffs({mm1, mm2})
      assert [1] == diff_keys
    end

    test "can do diff in steps (save transmitting data)" do
      mm1 = MerkleMap.new(1..100_000, fn x -> {x, x} end) |> MerkleMap.update_hashes()

      mm2 = MerkleMap.new(2..100_001, fn x -> {x, x} end) |> MerkleMap.update_hashes()

      assert {:ok, keys} = MerkleMap.diff_keys(mm1, mm2)
      assert Enum.sort([1, 100_001]) == Enum.sort(keys)

      assert {:ok, diff_keys} = do_partial_diffs({mm1, mm2})
      assert Enum.sort([1, 100_001]) == Enum.sort(diff_keys)
    end

    def do_truncated_partial_diffs({mm1, mm2}, max_diffs) do
      {:continue, partial_diff} = MerkleMap.prepare_partial_diff(mm1, 8)
      do_truncated_partial_diffs(partial_diff, {mm2, mm1}, max_diffs)
    end

    def do_truncated_partial_diffs(partial_diff, {mm1, mm2}, max_diffs) do
      case MerkleMap.continue_partial_diff(partial_diff, mm1, 8) do
        {:continue, partial_diff} ->
          partial_diff = MerkleMap.truncate_diff(partial_diff, max_diffs)
          do_truncated_partial_diffs(partial_diff, {mm2, mm1}, max_diffs)

        {:ok, diffs} ->
          {:ok, diffs}
      end
    end

    test "using diff truncation" do
      mm1 = MerkleMap.new(1..5000, fn x -> {x, x} end) |> MerkleMap.update_hashes()

      mm2 = MerkleMap.new(4500..5000, fn x -> {x, x} end) |> MerkleMap.update_hashes()

      update_with_truncated_diffs = fn mm1, mm2, truncate ->
        {:ok, diff_keys} = do_truncated_partial_diffs({mm1, mm2}, truncate)

        Enum.reduce(diff_keys, mm2, fn x, mm ->
          MerkleMap.put(mm, x, x)
        end)
        |> MerkleMap.update_hashes()
      end

      mm2 =
        Enum.reduce(1..8, mm2, fn _x, mm2 ->
          mm2 = update_with_truncated_diffs.(mm1, mm2, 500)
          refute MerkleMap.equal?(mm1, mm2)
          mm2
        end)

      mm2 = update_with_truncated_diffs.(mm1, mm2, 500)
      assert MerkleMap.equal?(mm1, mm2)
    end
  end

  describe "MerkleMap.equal?/2" do
    test "computes equality" do
      mm1 = MerkleMap.new(%{"foo" => "bar"}) |> MerkleMap.update_hashes()
      mm2 = MerkleMap.new(%{"foo" => "bar"}) |> MerkleMap.update_hashes()
      assert MerkleMap.equal?(mm1, mm2)
    end

    test "detects inequality of values" do
      mm1 = MerkleMap.new(%{"foo" => "bar"}) |> MerkleMap.update_hashes()
      mm2 = MerkleMap.new(%{"foo" => "baz"}) |> MerkleMap.update_hashes()
      refute MerkleMap.equal?(mm1, mm2)
    end

    test "detects inequality of keys" do
      mm1 = MerkleMap.new(%{"foo" => "bar"}) |> MerkleMap.update_hashes()
      mm2 = MerkleMap.new(%{"food" => "bar"}) |> MerkleMap.update_hashes()
      refute MerkleMap.equal?(mm1, mm2)
    end

    test "detects presence of other key" do
      mm1 = MerkleMap.new(%{"foo" => "bar"}) |> MerkleMap.update_hashes()
      mm2 = MerkleMap.new(%{"foo" => "bar", "other_key" => false}) |> MerkleMap.update_hashes()
      refute MerkleMap.equal?(mm1, mm2)
    end

    test "detects absence of key" do
      mm1 = MerkleMap.new(%{"foo" => "bar"}) |> MerkleMap.update_hashes()
      mm2 = MerkleMap.new(%{}) |> MerkleMap.update_hashes()
      refute MerkleMap.equal?(mm1, mm2)
    end
  end

  describe "MerkleMap.values/1" do
    test "returns same as Map" do
      map = %{"one" => "1", "two" => "2"}
      assert Map.values(map) == MerkleMap.values(MerkleMap.new(map))
    end
  end

  describe "MerkleMap.drop/2" do
    test "drops the correct keys" do
      map = %{one: 1, two: 2, three: 3}

      assert MerkleMap.equal?(
               MerkleMap.new(map)
               |> MerkleMap.drop([:two, :three])
               |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 1}) |> MerkleMap.update_hashes()
             )
    end
  end

  describe "MerkleMap.take/2" do
    test "takes only the required keys" do
      map = %{one: 1, two: 2, three: 3}

      assert MerkleMap.equal?(
               MerkleMap.new(map) |> MerkleMap.take([:one]) |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 1}) |> MerkleMap.update_hashes()
             )
    end
  end

  describe "MerkleMap.merge/2" do
    test "merges all keys" do
      mm1 = %{one: 1} |> MerkleMap.new() |> MerkleMap.update_hashes()
      mm2 = %{two: 2} |> MerkleMap.new() |> MerkleMap.update_hashes()

      assert MerkleMap.equal?(
               MerkleMap.merge(mm1, mm2) |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 1, two: 2}) |> MerkleMap.update_hashes()
             )
    end

    test "merges from second argument into first" do
      mm1 = %{one: 1} |> MerkleMap.new() |> MerkleMap.update_hashes()
      mm2 = %{one: 2} |> MerkleMap.new() |> MerkleMap.update_hashes()

      assert 2 =
               MerkleMap.merge(mm1, mm2)
               |> MerkleMap.get(:one)
    end
  end

  describe "MerkleMap.merge/3" do
    test "merges using supplied merge function" do
      mm1 = %{one: 1} |> MerkleMap.new() |> MerkleMap.update_hashes()
      mm2 = %{one: 2} |> MerkleMap.new() |> MerkleMap.update_hashes()

      assert MerkleMap.equal?(
               MerkleMap.new(%{one: 3}) |> MerkleMap.update_hashes(),
               MerkleMap.merge(mm1, mm2, fn :one, 1, 2 -> 3 end) |> MerkleMap.update_hashes()
             )
    end

    test "merges keys only present in one map without merge function" do
      mm1 = %{one: 1} |> MerkleMap.new() |> MerkleMap.update_hashes()
      mm2 = %{two: 2} |> MerkleMap.new() |> MerkleMap.update_hashes()

      assert MerkleMap.equal?(
               MerkleMap.new(%{one: 1, two: 2}) |> MerkleMap.update_hashes(),
               MerkleMap.merge(mm1, mm2, fn _, _, _ -> :overridden end)
               |> MerkleMap.update_hashes()
             )
    end
  end

  describe "MerkleMap.pop/2" do
    test "pops the value" do
      mm = %{one: 1, two: 2} |> MerkleMap.new()
      assert {1, new_mm} = MerkleMap.pop(mm, :one)

      assert MerkleMap.equal?(
               MerkleMap.update_hashes(new_mm),
               MerkleMap.update_hashes(MerkleMap.new(%{two: 2}))
             )
    end
  end

  describe "MerkleMap.pop_lazy/3" do
    test "pops the value if it exists" do
      mm = %{one: 1, two: 2} |> MerkleMap.new()
      assert {1, new_mm} = MerkleMap.pop_lazy(mm, :one, fn -> 13 end)

      assert MerkleMap.equal?(
               new_mm |> MerkleMap.update_hashes(),
               MerkleMap.new(%{two: 2}) |> MerkleMap.update_hashes()
             )
    end

    test "uses the function if the value does not exist" do
      mm = %{one: 1, two: 2} |> MerkleMap.new() |> MerkleMap.update_hashes()

      assert {13, new_mm} = MerkleMap.pop_lazy(mm, :three, fn -> 13 end)

      assert MerkleMap.equal?(new_mm |> MerkleMap.update_hashes(), mm)
    end
  end

  describe "MerkleMap.put_new/3" do
    test "puts a new value" do
      assert MerkleMap.equal?(
               MerkleMap.new(%{one: 1}) |> MerkleMap.update_hashes(),
               MerkleMap.new() |> MerkleMap.put_new(:one, 1) |> MerkleMap.update_hashes()
             )
    end

    test "does not overwrite an existing value" do
      assert MerkleMap.equal?(
               MerkleMap.new(%{one: 1}) |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 1}) |> MerkleMap.put_new(:one, 2) |> MerkleMap.update_hashes()
             )
    end
  end

  describe "MerkleMap.put_new_lazy/3" do
    test "puts a new value" do
      assert MerkleMap.equal?(
               MerkleMap.new(%{one: 1}) |> MerkleMap.update_hashes(),
               MerkleMap.new()
               |> MerkleMap.put_new_lazy(:one, fn -> 1 end)
               |> MerkleMap.update_hashes()
             )
    end

    test "does not overwrite an existing value" do
      assert MerkleMap.equal?(
               MerkleMap.new(%{one: 1}) |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 1})
               |> MerkleMap.put_new_lazy(:one, fn -> 2 end)
               |> MerkleMap.update_hashes()
             )
    end
  end

  describe "MerkleMap.get_lazy/3" do
    test "gets a value that exists" do
      mm = MerkleMap.new(%{one: 1})
      assert 1 = MerkleMap.get_lazy(mm, :one, fn -> 2 end)
    end

    test "computes a value that doesn't exist" do
      mm = MerkleMap.new(%{one: 1})
      assert 2 = MerkleMap.get_lazy(mm, :two, fn -> 2 end)
    end

    test "returns computed value if the key exists and value is nil" do
      map = %{none: nil}
      mm = MerkleMap.new(map)
      assert nil == Map.get_lazy(map, :none, fn -> :not_nil end)
      assert nil == MerkleMap.get_lazy(mm, :none, fn -> :not_nil end)
    end
  end

  describe "MerkleMap.split/2" do
    test "returns the correct merkle maps" do
      mm = MerkleMap.new(%{one: 1, two: 2, three: 3})

      assert {MerkleMap.new(%{one: 1}), MerkleMap.new(%{two: 2, three: 3})} ==
               MerkleMap.split(mm, [:one])
    end
  end

  describe "MerkleMap.update/4" do
    test "sets initial value" do
      mm =
        MerkleMap.new() |> MerkleMap.update(:one, 1, fn _ -> 2 end) |> MerkleMap.update_hashes()

      mm_compare = MerkleMap.new(%{one: 1}) |> MerkleMap.update_hashes()
      assert MerkleMap.equal?(mm, mm_compare)
    end

    test "updates value value" do
      mm =
        MerkleMap.new(%{one: 1})
        |> MerkleMap.update(:one, 1, fn 1 -> 2 end)
        |> MerkleMap.update_hashes()

      mm_compare = MerkleMap.new(%{one: 2}) |> MerkleMap.update_hashes()
      assert MerkleMap.equal?(mm, mm_compare)
    end
  end

  describe "MerkleMap.update!/3" do
    test "raises when key doesn't exist" do
      mm = MerkleMap.new()
      assert_raise(KeyError, fn -> MerkleMap.update!(mm, :one, fn _ -> 1 end) end)
    end

    test "updates the key when it is found" do
      mm = MerkleMap.new(%{one: 1})

      assert MerkleMap.equal?(
               MerkleMap.update!(mm, :one, fn 1 -> 2 end) |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 2}) |> MerkleMap.update_hashes()
             )
    end
  end

  describe "MerkleMap.replace!/3" do
    test "raises when key doesn't exist" do
      mm = MerkleMap.new()
      assert_raise(KeyError, fn -> MerkleMap.replace!(mm, :one, 1) end)
    end

    test "updates the key when it is found" do
      mm = MerkleMap.new(%{one: 1})

      assert MerkleMap.equal?(
               MerkleMap.replace!(mm, :one, 2) |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 2}) |> MerkleMap.update_hashes()
             )
    end
  end

  describe "MerkleMap.get_and_update/3" do
    test "updates and returns if the key exists" do
      mm = MerkleMap.new(%{one: 1})
      assert {1, mm_compare} = MerkleMap.get_and_update(mm, :one, fn 1 -> {1, 2} end)

      assert MerkleMap.equal?(
               mm_compare |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 2}) |> MerkleMap.update_hashes()
             )
    end

    test "sets and returns if the key does not exist" do
      mm = MerkleMap.new()
      assert {1, mm_compare} = MerkleMap.get_and_update(mm, :one, fn nil -> {1, 2} end)

      assert MerkleMap.equal?(
               mm_compare |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 2}) |> MerkleMap.update_hashes()
             )
    end
  end

  describe "MerkleMap.get_and_update!/3" do
    test "updates and returns if the key exists" do
      mm = MerkleMap.new(%{one: 1}) |> MerkleMap.update_hashes()
      assert {1, mm_compare} = MerkleMap.get_and_update!(mm, :one, fn 1 -> {1, 2} end)

      assert MerkleMap.equal?(
               mm_compare |> MerkleMap.update_hashes(),
               MerkleMap.new(%{one: 2}) |> MerkleMap.update_hashes()
             )
    end

    test "raises if the key does not exist" do
      mm = MerkleMap.new()
      assert_raise(KeyError, fn -> MerkleMap.get_and_update!(mm, :one, fn 1 -> {1, 2} end) end)
    end
  end
end
