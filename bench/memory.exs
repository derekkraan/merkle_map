defmodule MemoryHelper do
  def memory_kb(term) do
    (:erts_debug.flat_size(term) / 8.0 / :math.pow(2, 10))
    |> Float.round(1)
  end

  def wire_kb(term) do
    (byte_size(:erlang.term_to_binary(term)) / :math.pow(2, 10))
    |> Float.round(1)
  end
end

mm1 = MerkleMap.new(1..10000, fn x -> {x, x} end)

mm2 = MerkleMap.new(2..10001, fn x -> {x, x} end)

IO.inspect({FullMerkleMapMemory, MemoryHelper.memory_kb(mm1)})
IO.inspect({FullMerkleMapWire, MemoryHelper.wire_kb(mm1)})

m = Map.new(1..10000, fn x -> {x, x} end)

IO.inspect({MapMemory, MemoryHelper.memory_kb(m)})
IO.inspect({MapWire, MemoryHelper.wire_kb(m)})

{:ok, diff_keys} = MerkleMap.diff_keys(mm1, mm2)
Enum.sort([1, 10001]) == Enum.sort(diff_keys)

{:continue, first_partial} = MerkleMap.prepare_partial_diff(mm1, 8)
{:continue, second_partial} = MerkleMap.diff_keys(first_partial, mm2, 8)
{:continue, third_partial} = MerkleMap.diff_keys(second_partial, mm1, 8)
{:continue, fourth_partial} = MerkleMap.diff_keys(third_partial, mm2, 8)

IO.inspect(
  {MerkleMapSyncInStages,
   Enum.map(
     [first_partial, second_partial, third_partial, fourth_partial],
     &MemoryHelper.memory_kb/1
   )}
)

IO.inspect(
  {MerkleMapSyncInStagesWire,
   Enum.map(
     [first_partial, second_partial, third_partial, fourth_partial],
     &MemoryHelper.wire_kb/1
   )}
)
