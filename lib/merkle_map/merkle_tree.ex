defmodule MerkleMap.MerkleTree do
  defstruct object: {"", nil, nil}

  def new() do
    %__MODULE__{}
  end

  def new(enum) do
    Enum.reduce(enum, %__MODULE__{}, fn {key, val}, tree ->
      put(tree, key, val)
    end)
    |> calculate_hash()
  end

  def hash(thing) do
    <<Murmur.hash_x86_32(thing)::size(32)>>
  end

  def location(key) do
    hash(key)
  end

  def equal?(%__MODULE__{object: {hash, _, _}}, %__MODULE__{object: {hash, _, _}}), do: true
  def equal?(_, _), do: false

  def keys(%__MODULE__{object: tree}), do: keys(tree)
  def keys({_hash, :partial}), do: ["partial"]
  def keys({_, a, b}), do: keys(a) ++ keys(b)
  def keys({_, values}), do: Map.keys(values)
  def keys(nil), do: []

  def all_leaves(nil, _loc), do: []

  def all_leaves({_, a, b}, loc) do
    all_leaves(a, <<loc::bitstring, 0::1>>) ++ all_leaves(b, <<loc::bitstring, 1::1>>)
  end

  def all_leaves({_, :partial}, loc), do: [{:partial, loc}]

  def all_leaves({_, values}, _loc), do: Map.keys(values)

  def diff_keys(tree1, tree2, loc \\ <<>>)

  def diff_keys(%__MODULE__{object: t1}, %__MODULE__{object: t2}, loc) do
    diff_keys(t1, t2, loc)
  end

  def diff_keys(nil, nil, _loc), do: []

  def diff_keys({h, _, _}, {h, _, _}, _loc) do
    []
  end

  def diff_keys(nil, {_, _, _} = tree, loc),
    do: all_leaves(tree, loc)

  def diff_keys({_, _, _} = tree, nil, loc),
    do: all_leaves(tree, loc)

  def diff_keys({_, :partial}, _, loc), do: [{:partial, loc}]
  def diff_keys(_, {_, :partial}, loc), do: [{:partial, loc}]

  def diff_keys(nil, {_, values}, _loc), do: Map.keys(values)

  def diff_keys({_, a1, a2}, {_, b1, b2}, loc) do
    diff_keys(a1, b1, <<loc::bitstring, 0::1>>) ++ diff_keys(a2, b2, <<loc::bitstring, 1::1>>)
  end

  def diff_keys({_, v1}, {_, v2}, _loc) do
    (Map.keys(v1) ++ Map.keys(v2))
    |> Enum.uniq()
    |> Enum.reject(fn x -> Map.get(v1, x) == Map.get(v2, x) end)
  end

  def prune_empty_nodes({_, nil, nil}), do: nil
  def prune_empty_nodes(tree), do: tree

  def calculate_hash(%__MODULE__{object: {_, a, b}}) do
    h_a = get_hash(a)
    h_b = get_hash(b)
    %__MODULE__{object: {hash(h_a <> h_b), a, b}}
  end

  def calculate_hash({_, a, b}) do
    h_a = get_hash(a)
    h_b = get_hash(b)
    {hash(h_a <> h_b), a, b}
  end

  defp get_hash({h, _values}), do: h
  defp get_hash({h, _a, _b}), do: h
  defp get_hash(nil), do: ""

  def partial_tree(tree, loc, levels)

  def partial_tree(%__MODULE__{object: tree}, loc, levels) do
    %__MODULE__{object: partial_tree(tree, loc, levels)}
  end

  def partial_tree(nil, _, _), do: nil

  def partial_tree({_, a, _b}, <<0::1, rest_loc::bits>>, levels),
    do: partial_tree(a, rest_loc, levels)

  def partial_tree({_, _a, b}, <<1::1, rest_loc::bits>>, levels),
    do: partial_tree(b, rest_loc, levels)

  def partial_tree({_, _} = tree, _loc, _levels) do
    tree
  end

  def partial_tree({hash, _, _}, <<>>, 0) do
    {hash, :partial}
  end

  def partial_tree(tree, <<>>, levels) do
    {hash, a, b} = tree
    {hash, partial_tree(a, <<>>, levels - 1), partial_tree(b, <<>>, levels - 1)}
  end

  def delete(%__MODULE__{object: tree}, key) do
    %__MODULE__{object: delete(tree, key)}
  end

  def delete(tree, key) do
    case delete(tree, location(key), key) do
      nil -> %__MODULE__{} |> calculate_hash()
      tree -> tree
    end
  end

  def delete(tree, <<0::size(1), rest_loc::bits>>, key) do
    {hash, first, second} = init_empty_inner_node(tree)
    new_first = delete(first, rest_loc, key)
    {hash, new_first, second} |> calculate_hash() |> prune_empty_nodes()
  end

  def delete(tree, <<1::size(1), rest_loc::bits>>, key) do
    {hash, first, second} = init_empty_inner_node(tree)
    new_second = delete(second, rest_loc, key)
    {hash, first, new_second} |> calculate_hash() |> prune_empty_nodes()
  end

  def delete(tree, <<>>, key) do
    {_, values} = init_empty_leaf(tree)
    new_values = Map.delete(values, key)

    if Map.size(new_values) == 0 do
      nil
    else
      {hash(new_values), new_values}
    end
  end

  def put(%__MODULE__{object: tree}, key, value) do
    %__MODULE__{object: put(tree, key, value)}
  end

  def put(tree, key, value) do
    put(tree, location(key), key, value)
  end

  defp put(tree, <<0::size(1), rest_loc::bits>>, k, v) do
    {_hash, a, b} = init_empty_inner_node(tree)
    new_a = put(a, rest_loc, k, v)
    {nil, new_a, b} |> calculate_hash()
  end

  defp put(tree, <<1::size(1), rest_loc::bits>>, k, v) do
    {_hash, a, b} = init_empty_inner_node(tree)
    new_b = put(b, rest_loc, k, v)
    {nil, a, new_b} |> calculate_hash()
  end

  defp put(tree, <<>>, key, value) do
    {_h, values} = init_empty_leaf(tree)
    new_values = Map.put(values, key, hash(value))
    {hash(new_values), new_values}
  end

  defp init_empty_leaf({_hash, _value} = tree), do: tree
  defp init_empty_leaf(nil), do: {nil, %{}}

  defp init_empty_inner_node({_hash, _a, _b} = tree), do: tree
  defp init_empty_inner_node(nil), do: {nil, nil, nil}
end
