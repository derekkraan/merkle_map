defmodule MerkleMap.MerkleTreeImpl do
  ###
  # This data structure has the following shapes:
  # [] - empty branch
  # {hash, branch1, branch2} - inner node
  # {hash, {key_hash, contents}} - leaf node
  #

  @empty_hash []
  @empty_branch []

  @type empty_branch :: []
  @type empty_hash :: []
  @type leaf :: {hash(), {hash(), contents :: term()}}
  @type inner_node :: {hash(), branch(), branch()}
  @type branch :: leaf() | inner_node() | empty_branch()
  @type hash() :: empty_hash() | binary()

  @levels 32
  @hash_limit round(:math.pow(2, @levels))

  def new() do
    @empty_branch
  end

  def new(enum) do
    Enum.reduce(enum, new(), fn {k, v}, tree ->
      put(tree, k, v)
    end)
  end

  def put(tree, k, v) do
    hash_k = hash(k)
    put_leaf(tree, hash_k, {hash_k, %{k => v}})
  end

  def put_leaf(@empty_branch, _rest_hash_k, leaf_node) do
    {@empty_hash, leaf_node}
  end

  def put_leaf({_hash, branch_l, branch_r}, <<direction::size(1), rest_hash_k::bits>>, leaf_node) do
    case direction do
      0 ->
        {@empty_hash, put_leaf(branch_l, rest_hash_k, leaf_node), branch_r}

      1 ->
        {@empty_hash, branch_l, put_leaf(branch_r, rest_hash_k, leaf_node)}
    end
  end

  def put_leaf({_, {hash_k, found_map}}, _rest_hash_k, {hash_k, new_map}) do
    {@empty_hash, {hash_k, Map.merge(found_map, new_map)}}
  end

  def put_leaf({_, _} = found_leaf_node, rest_hash_k, leaf_node) do
    discard_bits = @levels - bit_size(rest_hash_k)

    {_, {<<_::size(discard_bits), found_leaf_direction::size(1), _::bits>>, _}} = found_leaf_node

    case found_leaf_direction do
      0 ->
        {@empty_hash, found_leaf_node, @empty_branch}

      1 ->
        {@empty_hash, @empty_branch, found_leaf_node}
    end
    |> put_leaf(rest_hash_k, leaf_node)
  end

  def delete(tree, key) do
    delete(tree, hash(key), key)
  end

  def delete(@empty_branch, _hash_k, _k) do
    @empty_branch
  end

  def delete({_, {hash_k, contents}}, _hash, k) do
    new_contents = Map.delete(contents, k)

    case new_contents do
      empty_map when map_size(empty_map) == 0 -> @empty_branch
      contents -> {@empty_hash, {hash_k, contents}}
    end
  end

  def delete({_, _} = leaf_node, _hash_k, _k), do: leaf_node

  def delete({_, branch_l, branch_r}, <<direction::size(1), rest_hash_k::bits>>, key) do
    case direction do
      0 -> {@empty_hash, delete(branch_l, rest_hash_k, key), branch_r}
      1 -> {@empty_hash, branch_l, delete(branch_r, rest_hash_k, key)}
    end
    |> case do
      {_, @empty_branch, @empty_branch} -> @empty_branch
      {_, @empty_branch, {_, _} = leaf_node} -> leaf_node
      {_, {_, _} = leaf_node, @empty_branch} -> leaf_node
      tree -> tree
    end
  end

  def equal?(tree1, tree2) do
    {_, tree1} = calculate_hashes(tree1)
    {_, tree2} = calculate_hashes(tree2)
    {tree1, tree2, check_equal(tree1, tree2)}
  end

  def check_equal({hash, _}, {hash, _}), do: true
  def check_equal({hash, _, _}, {hash, _, _}), do: true
  def check_equal(@empty_branch, @empty_branch), do: true
  def check_equal(_, _), do: false

  def diff_keys(t1, t2) do
    {_h, t1} = calculate_hashes(t1)
    {_h, t2} = calculate_hashes(t2)

    {t1, t2, List.flatten(diff_keys(t1, t2, 0)) |> remove_tuple_wrappers()}
  end

  def diff_keys(@empty_branch, tree, _levels), do: raw_keys(tree)
  def diff_keys(tree, @empty_branch, _levels), do: raw_keys(tree)

  def diff_keys({hash, _, _}, {hash, _, _}, _levels), do: []

  def diff_keys({_, t1_l, t1_r}, {_, t2_l, t2_r}, levels) do
    [diff_keys(t1_l, t2_l, levels + 1), diff_keys(t1_r, t2_r, levels + 1)]
  end

  def diff_keys({hash, _}, {hash, _}, _levels), do: []

  def diff_keys({_, leaf1}, {_, leaf2}, _levels) do
    {_, map1} = leaf1
    {_, map2} = leaf2
    raw_keys_1 = Map.keys(map1)
    raw_keys_2 = Map.keys(map2)

    [
      Enum.reject(raw_keys_1, fn k ->
        Map.get(map1, k) == Map.get(map2, k)
      end),
      raw_keys_2 -- raw_keys_1
    ]
    |> Enum.map(&add_tuple_wrappers/1)
  end

  def diff_keys({_, _, _} = inner_node, {_, _} = leaf, levels),
    do: diff_keys(leaf, inner_node, levels)

  def diff_keys({_, _} = leaf, {_, b_l, b_r} = _inner_node, levels) do
    {_, {<<_discard::size(levels), direction::size(1), _rest::bits>>, _}} = leaf

    case direction do
      0 ->
        [diff_keys(b_l, leaf, levels + 1), raw_keys(b_r)]

      1 ->
        [raw_keys(b_l), diff_keys(b_r, leaf, levels + 1)]
    end
  end

  def keys(tree), do: remove_tuple_wrappers(List.flatten(raw_keys(tree)))

  defp raw_keys(@empty_branch), do: []
  defp raw_keys({_, b_l, b_r}), do: [raw_keys(b_l), raw_keys(b_r)]
  defp raw_keys({_, {_, contents}}), do: Map.keys(contents) |> add_tuple_wrappers()

  defp calculate_hashes(@empty_branch), do: {@empty_hash, @empty_branch}

  defp calculate_hashes({@empty_hash, b_l, b_r}) do
    {hash_l, b_l} = calculate_hashes(b_l)
    {hash_r, b_r} = calculate_hashes(b_r)
    total_hash = hash({hash_l, hash_r})
    {total_hash, {total_hash, b_l, b_r}}
  end

  defp calculate_hashes({hash, _, _} = inner_node), do: {hash, inner_node}

  defp calculate_hashes({@empty_hash, {hash_key, contents}}) do
    c_hash = hash(contents)
    new_leaf = {c_hash, {hash_key, contents}}
    {c_hash, new_leaf}
  end

  defp calculate_hashes({hash, _} = leaf) do
    {hash, leaf}
  end

  defp hash(x) do
    <<:erlang.phash2(x, @hash_limit)::size(@levels)>>
  end

  defp add_tuple_wrappers(keys) do
    Enum.map(keys, fn x -> {x} end)
  end

  defp remove_tuple_wrappers(raw_keys) do
    Enum.map(raw_keys, fn {x} -> x end)
  end
end
