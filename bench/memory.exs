defmodule MemoryHelper do
  def memory_kb(term) do
    :erts_debug.flat_size(term) * 8.0 / :math.pow(2, 10)
  end
end

mm = MerkleMap.new(1..10000, fn x -> {x, x} end)

IO.inspect({FullMerkleMap, MemoryHelper.memory_kb(mm)})

m = Map.new(1..10000, fn x -> {x, x} end)
IO.inspect({Map, MemoryHelper.memory_kb(m)})
