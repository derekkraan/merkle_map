# MerkleMap

MerkleMap is an augmented "plain" Map. Certain operations are faster, and others are slower. MerkleMap also requires more memory, so be aware of this.

MerkleMap is almost a drop-in replacement for Map. It has the same functions, with the following additions:

- `MerkleMap.diff_keys/2` returns the keys that differ between two merkle maps.
- `MerkleMap.prepare_partial_diff/2` prepares a partial diff.
- `MerkleMap.continue_partial_diff/3` continues the partial diff.
- `MerkleMap.update_hashes/1` updates the hashes in the merkle map.

When mutating the merkle map, hashes are not automatically updated. Hashes must be updated manually. This is both for performance, but also to keep function signatures from getting too silly. Functions that accept two merkle maps (eg, `merge/2`) will require that you have run `update_hashes/1` on both input maps, or an ArgumentError will be raised.

`prepare_partial_diff/2` and `continue_partial_diff/3` are built for use when comparing two maps that are not present in the same process or perhaps not even on the same node. By sending and comparing only a part of the merkle tree in each step, it is possible to send much less traffic back and forth. This is especially a concern for large maps.

## Benchmarks

```
##### With input 100_000 #####                                                              
Name                             ips        average  deviation         median         99th %
merkle_map_not_equal_2       35.27 M     0.00003 ms±100268.45%           0 ms           0 ms
merkle_map_equal_2           26.76 M     0.00004 ms ±98106.44%           0 ms           0 ms
map_put_3                    13.87 M     0.00007 ms  ±8711.21%           0 ms     0.00133 ms
merkle_map_put_3            0.0798 M      0.0125 ms  ±3058.31%     0.00723 ms      0.0130 ms
merkle_map_merge_2          0.0370 M      0.0270 ms  ±2246.31%      0.0162 ms      0.0338 ms
map_not_equal_2            0.00099 M        1.01 ms     ±7.78%        1.00 ms        1.37 ms
map_equal_2                0.00094 M        1.06 ms    ±12.97%        1.02 ms        1.68 ms
map_merge_2                0.00059 M        1.71 ms    ±34.77%        1.62 ms        2.59 ms
```

## Installation

This package can be installed by adding `merkle_map` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:merkle_map, "~> 0.2.0"},
  ]
end
```

The docs can be found at [https://hexdocs.pm/merkle_map](https://hexdocs.pm/merkle_map).
