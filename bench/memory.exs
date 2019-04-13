defmodule MemoryHelper do
  def memory_kb(term) do
    :erts_debug.flat_size(term) * 8.0 / :math.pow(2, 10)
  end
end

mm1 = MerkleMap.new(1..10000, fn x -> {x, x} end)

mm2 = MerkleMap.new(2..10001, fn x -> {x, x} end)

IO.inspect({FullMerkleMap, MemoryHelper.memory_kb(mm1)})

m = Map.new(1..10000, fn x -> {x, x} end)

IO.inspect({Map, MemoryHelper.memory_kb(m)})

Enum.sort([1, 10001]) == Enum.sort(MerkleMap.diff_keys(mm1, mm2))

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
