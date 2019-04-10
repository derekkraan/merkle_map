prepare = fn number ->
  m = Map.new(1..number, fn x -> {x, x} end)
  mm = MerkleMap.new(1..number, fn x -> {x, x} end)
  {m, Map.put(m, 500, 501), mm, MerkleMap.put(mm, 500, 501)}
end

Benchee.run(
  %{
    merkle_map_put_3: fn {_m, _m2, mm, _mm2} -> MerkleMap.put(mm, "a", "foo") end,
    map_put_3: fn {m, _m2, _mm, _mm2} -> Map.put(m, "a", "foo") end,
    merkle_map_merge_2: fn {_m, _m2, mm, mm2} -> MerkleMap.merge(mm, mm2) end,
    map_merge_2: fn {m, m2, _mm, _mm2} -> Map.merge(m, m2) end,
    merkle_map_equal_2: fn {_m, _m2, mm, _mm2} -> MerkleMap.equal?(mm, mm) end,
    map_equal_2: fn {m, _m2, mm, _mm2} -> Map.equal?(m, mm.map) end,
    merkle_map_not_equal_2: fn {_m, _m2, mm, mm2} -> MerkleMap.equal?(mm, mm2) end,
    map_not_equal_2: fn {m, m2, _mm, _mm2} -> Map.equal?(m, m2) end
  },
  inputs: %{"10_000" => prepare.(10_000), "100_000" => prepare.(100_000)},
  time: 5,
  memory_time: 2
)
