# MerkleMap

MerkleMap is an augmented "plain" Map. Certain operations are faster, and others are slower. MerkleMap also requires more memory, so be aware of this.

MerkleMap is a drop-in replacement for Map.

## Benchmarks

```
##### With input 100_000 #####                                                               
Name                             ips        average  deviation         median         99th % 
merkle_map_not_equal_2       29.68 M      0.0337 μs±140140.94%           0 μs           0 μs 
merkle_map_equal_2           26.57 M      0.0376 μs±120079.35%           0 μs           0 μs 
map_put_3                     3.48 M        0.29 μs ±62046.73%           0 μs        1.19 μs 
merkle_map_put_3            0.0299 M       33.45 μs   ±423.46%       32.51 μs       52.15 μs 
merkle_map_merge_2          0.0216 M       46.27 μs    ±22.46%       43.23 μs       90.85 μs 
map_equal_2                0.00103 M      973.70 μs     ±4.77%      971.72 μs     1083.10 μs 
map_not_equal_2            0.00096 M     1036.80 μs    ±11.78%     1003.98 μs     1617.23 μs 
map_merge_2                0.00064 M     1553.92 μs    ±62.33%     1524.15 μs     1839.37 μs 
```

## Installation

This package can be installed by adding `merkle_map` and `murmur` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:merkle_map, "~> 0.1.0"},
    {:murmur, "~> 1.0"}
  ]
end
```

Using another hash function. By default MerkleMap will use `Murmur` for hashing, but if you already have another hash library as a dependency in your app then you might want to re-use that library. Simply implement the `MerkleMap.Hash` behaviour and add the following configuration to your mix config:

```elixir
config :merkle_map, hash_module: MyHash
```

The docs can be found at [https://hexdocs.pm/merkle_map](https://hexdocs.pm/merkle_map).

