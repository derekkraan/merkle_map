# MerkleMap

MerkleMap is an augmented "plain" Map. Certain operations are faster, and others are slower. MerkleMap also requires more memory, so be aware of this.

MerkleMap is a drop-in replacement for Map.

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

