prepare_cold = fn number ->
  m = Map.new(1..number, fn x -> {x, x} end)
  mm = MerkleMap.new(1..number, fn x -> {x, x} end)
  {m, Map.put(m, 500, 501), mm, MerkleMap.put(mm, 500, 501)}
end

prepare_warm = fn number ->
  {m, m2, mm, mm2} = prepare_cold.(number)
  {:ok, mm, mm2, _} = MerkleMap.diff_keys(mm, mm2)
  {m, m2, mm, mm2}
end

Benchee.run(
  %{
    merkle_map_put_3: fn {_m, _m2, mm, _mm2} -> MerkleMap.put(mm, "a", "foo") end,
    map_put_3: fn {m, _m2, _mm, _mm2} -> Map.put(m, "a", "foo") end,
    merkle_map_merge_2: fn {_m, _m2, mm, mm2} -> MerkleMap.merge(mm, mm2) end,
    map_merge_2: fn {m, m2, _mm, _mm2} -> Map.merge(m, m2) end
    # merkle_map_equal_2: fn {_m, _m2, mm, _mm2} -> MerkleMap.equal?(mm, mm) end,
    # map_equal_2: fn {m, _m2, mm, _mm2} -> Map.equal?(m, mm.map) end,
    # merkle_map_not_equal_2: fn {_m, _m2, mm, mm2} -> MerkleMap.equal?(mm, mm2) end,
    # map_not_equal_2: fn {m, m2, _mm, _mm2} -> Map.equal?(m, m2) end
  },
  inputs: %{
    "100_000_cold" => prepare_cold.(100_000),
    "100_000_warm" => prepare_warm.(100_000)
  },
  time: 5
)
