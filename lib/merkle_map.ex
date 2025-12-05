defmodule MerkleMap do
  @moduledoc """
  `MerkleMap` is a mostly-drop-in replacement for [`Map`](https://hexdocs.pm/elixir/Map.html#functions) that optimizes certain operations, making heavy use of [Merkle trees](https://en.wikipedia.org/wiki/Merkle_tree).

  `MerkleMap`-specific functions:

  - `update_hashes/1`
  - `diff_keys/2`
  - `truncate_diff/2`
  - `prepare_partial_diff/2`
  - `continue_partial_diff/3`
  """

  alias MerkleMap.MerkleTree
  alias MerkleMap.MerkleTree.Diff

  defstruct map: %{},
            merkle_tree: MerkleTree.new()

  @opaque t() :: %__MODULE__{}

  @doc """
  Creates a new empty MerkleMap.
  """
  def new() do
    %__MODULE__{}
  end

  @doc """
  Creates a new MerkleMap from an enumerable.
  """
  def new(enum) do
    Enum.reduce(enum, new(), fn {k, v}, mm -> put(mm, k, v) end)
  end

  @doc """
  Creates a new MerkleMap from an enumerable via the transformation function.
  """
  def new(enum, tform) do
    Enum.reduce(enum, new(), fn elem, mm ->
      {k, v} = tform.(elem)
      put(mm, k, v)
    end)
  end

  @doc """
  Deletes the entry in the MerkleMap for a specific key.
  """
  def delete(%__MODULE__{} = mm, k) do
    %{mm | map: Map.delete(mm.map, k), merkle_tree: MerkleTree.delete(mm.merkle_tree, k)}
  end

  @doc """
  Returns whether a given key exists in the given MerkleMap.
  """
  def has_key?(%__MODULE__{map: m}, k) do
    Map.has_key?(m, k)
  end

  @doc """
  Checks if two MerkleMaps are equal.
  """
  def equal?(mm1, mm2) do
    MerkleTree.equal?(mm1.merkle_tree, mm2.merkle_tree)
  end

  @doc """
  Puts the given value under key.
  """
  def put(%__MODULE__{} = mm, k, v) do
    %{mm | map: Map.put(mm.map, k, v), merkle_tree: MerkleTree.put(mm.merkle_tree, k, v)}
  end

  @doc """
  Returns all values from the MerkleMap.
  """
  def values(%__MODULE__{} = mm) do
    Map.values(mm.map)
  end

  @doc """
  Fetches the value for a specific key and returns it in a tuple.
  """
  def fetch(mm, key) do
    Map.fetch(mm.map, key)
  end

  @doc """
  Fetches the value for a specific key, erroring if it does not exist.
  """
  def fetch!(mm, key) do
    Map.fetch!(mm.map, key)
  end

  @doc """
  Converts the MerkleMap to a list.
  """
  def to_list(mm) do
    Map.to_list(mm.map)
  end

  @doc """
  Converts a struct to a MerkleMap.
  """
  def from_struct(struct) do
    Map.from_struct(struct) |> new()
  end

  @doc """
  Gets the value for a specific key.
  """
  def get(mm, key, default \\ nil) do
    Map.get(mm.map, key, default)
  end

  @doc """
  Returns all keys from the MerkleMap.
  """
  def keys(mm) do
    Map.keys(mm.map)
  end

  @doc """
  Drops the given keys from the MerkleMap.
  """
  def drop(%__MODULE__{} = mm, keys) do
    mm = %{mm | map: Map.drop(mm.map, keys)}

    new_mm =
      Enum.reduce(keys, mm.merkle_tree, fn key, mt ->
        MerkleTree.delete(mt, key)
      end)

    Map.put(mm, :merkle_tree, new_mm)
  end

  @doc """
  Takes all entries corresponding to the given keys and returns them in a new MerkleMap.
  """
  def take(%__MODULE__{} = mm, keys) do
    Map.take(mm.map, keys) |> new()
  end

  @doc """
  Updates the hashes in the underlying MerkleTree (using `:erlang.phash2/2`).

  Must be called after every Merkle map mutation.
  """
  def update_hashes(%__MODULE__{} = mm) do
    %{mm | merkle_tree: MerkleTree.update_hashes(mm.merkle_tree)}
  end

  @doc """
  Returns the keys that are different between two MerkleMaps.

  ## Examples

      iex> mm1 = MerkleMap.new(%{a: 1, b: 2}) |> MerkleMap.update_hashes()
      iex> mm2 = MerkleMap.new(%{a: 1, b: 3}) |> MerkleMap.update_hashes()
      iex> MerkleMap.diff_keys(mm1, mm2)
      {:ok, [:b]}
  """
  def diff_keys(mm1, mm2)

  def diff_keys(%__MODULE__{} = mm1, %__MODULE__{} = mm2) do
    {:ok, MerkleTree.diff_keys(mm1.merkle_tree, mm2.merkle_tree)}
  end

  @doc """
  Prepares a partial diff of the MerkleMap's MerkleTree up to a certain depth.
  """
  def prepare_partial_diff(%__MODULE__{} = mm, depth) do
    MerkleTree.prepare_partial_diff(mm.merkle_tree, depth)
  end

  @doc """
  Continues a partial diff.
  """
  def continue_partial_diff(%__MODULE__{} = mm, %Diff{} = partial, depth) do
    MerkleTree.continue_partial_diff(mm.merkle_tree, partial, depth)
  end

  def continue_partial_diff(%Diff{} = partial, %__MODULE__{} = mm, depth) do
    MerkleTree.continue_partial_diff(mm.merkle_tree, partial, depth)
  end

  @doc """
  Truncates a diff to a certain amount.
  """
  defdelegate truncate_diff(diff, amount), to: Diff

  @doc """
  Merges two MerkleMaps into one.
  """
  def merge(mm1, mm2) do
    {:ok, diff_keys} = diff_keys(mm1, mm2)

    Enum.reduce(diff_keys, mm1, fn key, mm ->
      if Map.has_key?(mm2.map, key) do
        put(mm, key, get(mm2, key))
      else
        mm
      end
    end)
  end

  @doc """
  Merges two MerkleMaps into one with a callback to resolve conflicts.
  """
  def merge(mm1, mm2, update_fun) do
    {:ok, diff_keys} = diff_keys(mm1, mm2)

    Enum.reduce(diff_keys, mm1, fn key, mm ->
      cond do
        has_key?(mm, key) && has_key?(mm2, key) ->
          val = update_fun.(key, get(mm, key), get(mm2, key))
          put(mm, key, val)

        has_key?(mm2, key) ->
          put(mm, key, get(mm2, key))

        # then the key is only in mm
        true ->
          mm
      end
    end)
  end

  @doc """
  Returns and removes the value associated with key in the MerkleMap.
  """
  def pop(mm, key) do
    {val, map} = Map.pop(mm.map, key)
    {val, %{mm | map: map, merkle_tree: MerkleTree.delete(mm.merkle_tree, key)}}
  end

  @doc """
  Lazily returns and removes the value associated with key in the MerkleMap.
  """
  def pop_lazy(mm, key, fun) do
    {val, map} = Map.pop_lazy(mm.map, key, fun)
    {val, %{mm | map: map, merkle_tree: MerkleTree.delete(mm.merkle_tree, key)}}
  end

  @doc """
  Puts the given value under key unless the entry exists.
  """
  def put_new(mm, key, value) do
    if has_key?(mm, key) do
      mm
    else
      put(mm, key, value)
    end
  end

  @doc """
  Evaluates the function and puts the result under key unless the entry exists.
  """
  def put_new_lazy(mm, key, fun) do
    if has_key?(mm, key) do
      mm
    else
      put(mm, key, fun.())
    end
  end

  @doc """
  Gets the value for a specific key, executing the function if the key does not exist.
  """
  def get_lazy(mm, key, fun) do
    if has_key?(mm, key) do
      get(mm, key)
    else
      fun.()
    end
  end

  @doc """
  Splits the Merkle map into two Merkle maps according to the given keys.
  """
  def split(mm1, keys) do
    {take(mm1, keys), drop(mm1, keys)}
  end

  @doc """
  Updates the key in map with the given function.
  """
  def update(mm, key, initial, fun) do
    if has_key?(mm, key) do
      put(mm, key, fun.(get(mm, key)))
    else
      put(mm, key, initial)
    end
  end

  @doc """
  Updates the key with the given function, erroring if the key does not exist.
  """
  def update!(mm, key, fun) do
    map = Map.update!(mm.map, key, fun)
    %{mm | map: map, merkle_tree: MerkleTree.put(mm.merkle_tree, key, Map.get(map, key))}
  end

  @doc """
  Replaces the value under key, erroring if the key does not exist.
  """
  def replace!(mm, key, value) do
    map = Map.replace!(mm.map, key, value)
    %{mm | map: map, merkle_tree: MerkleTree.put(mm.merkle_tree, key, Map.get(map, key))}
  end

  @doc """
  Gets the value from key and updates it, all in one pass.
  """
  def get_and_update(mm, key, fun) do
    {val, map} = Map.get_and_update(mm.map, key, fun)
    new_mm = %{mm | map: map}
    new_mm = put(new_mm, key, get(new_mm, key))
    {val, new_mm}
  end

  @doc """
  Gets the value from key and updates it. Raises if there is no key.
  """
  def get_and_update!(mm, key, fun) do
    {val, map} = Map.get_and_update!(mm.map, key, fun)
    new_mm = %{mm | map: map}
    new_mm = put(new_mm, key, get(new_mm, key))
    {val, new_mm}
  end
end
