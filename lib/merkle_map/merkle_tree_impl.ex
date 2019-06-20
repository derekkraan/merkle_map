defmodule MerkleMap.MerkleTreeImpl do
  ###
  # This data structure has the following shapes:
  # [] - empty branch
  # {hash, branch1, branch2} - inner node
  # {hash, {key_hash, contents}} - leaf node
  #

  @moduledoc false

  @empty_hash []
  @empty_branch []

  @type empty_branch :: []
  @type empty_hash :: []
  @type leaf :: {hash(), {hash(), contents :: term()}}
  @type inner_node :: {hash(), branch(), branch()}
  @type branch :: leaf() | inner_node() | empty_branch()
  @type hash() :: empty_hash() | binary()

  @max_levels 32
  @hash_limit round(:math.pow(2, @max_levels))

  def new() do
    @empty_branch
  end

  def put(tree, k, v) do
    hash_k = hash(k)
    put_leaf(tree, hash_k, {hash_k, %{k => v}})
  end

  defp put_leaf(@empty_branch, _rest_hash_k, leaf_node) do
    {@empty_hash, leaf_node}
  end

  defp put_leaf({_hash, branch_l, branch_r}, <<direction::size(1), rest_hash_k::bits>>, leaf_node) do
    case direction do
      0 ->
        {@empty_hash, put_leaf(branch_l, rest_hash_k, leaf_node), branch_r}

      1 ->
        {@empty_hash, branch_l, put_leaf(branch_r, rest_hash_k, leaf_node)}
    end
  end

  defp put_leaf({_, {hash_k, found_map}}, _rest_hash_k, {hash_k, new_map}) do
    {@empty_hash, {hash_k, Map.merge(found_map, new_map)}}
  end

  defp put_leaf({_, _} = found_leaf_node, rest_hash_k, leaf_node) do
    discard_bits = @max_levels - bit_size(rest_hash_k)

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
    assert_hashes_calculated(tree1)
    assert_hashes_calculated(tree2)
    check_equal(tree1, tree2)
  end

  defp assert_hashes_calculated({@empty_hash, _, _}),
    do: raise(ArgumentError, "Must call MerkleMap.update_hashes/1 before calling this function.")

  defp assert_hashes_calculated({@empty_hash, _}),
    do: raise(ArgumentError, "Must call MerkleMap.update_hashes/1 before calling this function.")

  defp assert_hashes_calculated(_), do: nil

  defp check_equal({hash, _}, {hash, _}), do: true
  defp check_equal({hash, _, _}, {hash, _, _}), do: true
  defp check_equal(@empty_branch, @empty_branch), do: true
  defp check_equal(_, _), do: false

  def diff_keys(t1, t2, depth \\ 0) when is_integer(depth) do
    assert_hashes_calculated(t1)
    assert_hashes_calculated(t2)

    List.flatten(do_diff_keys(t1, t2, depth)) |> remove_tuple_wrappers()
  end

  defp do_diff_keys(@empty_branch, tree, _levels), do: raw_keys(tree)
  defp do_diff_keys(tree, @empty_branch, _levels), do: raw_keys(tree)

  defp do_diff_keys({hash, _, _}, {hash, _, _}, _levels), do: []

  defp do_diff_keys({_, t1_l, t1_r}, {_, t2_l, t2_r}, levels) do
    [do_diff_keys(t1_l, t2_l, levels + 1), do_diff_keys(t1_r, t2_r, levels + 1)]
  end

  defp do_diff_keys(_, {:partial, loc}, _levels) do
    [{:partial, loc}] |> add_tuple_wrappers()
  end

  defp do_diff_keys({:partial, loc}, _, _levels) do
    [{:partial, loc}] |> add_tuple_wrappers()
  end

  defp do_diff_keys({hash, _}, {hash, _}, _levels), do: []

  defp do_diff_keys({_, leaf1}, {_, leaf2}, _levels) do
    {_, map1} = leaf1
    {_, map2} = leaf2
    raw_keys_1 = Map.keys(map1)
    raw_keys_2 = Map.keys(map2)

    [
      add_tuple_wrappers(
        Enum.reject(raw_keys_1, fn k ->
          Map.get(map1, k) == Map.get(map2, k)
        end)
      ),
      add_tuple_wrappers(raw_keys_2 -- raw_keys_1)
    ]
  end

  defp do_diff_keys({_, _, _} = inner_node, {_, _} = leaf, levels),
    do: do_diff_keys(leaf, inner_node, levels)

  defp do_diff_keys({_, _} = leaf, {_, b_l, b_r} = _inner_node, levels) do
    {_, {<<_discard::size(levels), direction::size(1), _rest::bits>>, _}} = leaf

    case direction do
      0 ->
        [do_diff_keys(b_l, leaf, levels + 1), raw_keys(b_r)]

      1 ->
        [raw_keys(b_l), do_diff_keys(b_r, leaf, levels + 1)]
    end
  end

  def keys(tree), do: remove_tuple_wrappers(List.flatten(raw_keys(tree)))

  def subtree(tree, loc, depth) when is_integer(depth) and depth > 0 and is_bitstring(loc) do
    assert_hashes_calculated(tree)

    find_subtree(tree, loc)
    |> get_subtree(loc, depth)
  end

  defp find_subtree(@empty_branch, _loc), do: @empty_branch
  defp find_subtree({_, _} = leaf, _loc), do: leaf

  defp find_subtree({_, b_l, _}, <<0::size(1), rest_loc::bits>>),
    do: find_subtree(b_l, rest_loc)

  defp find_subtree({_, _, b_r}, <<1::size(1), rest_loc::bits>>),
    do: find_subtree(b_r, rest_loc)

  defp find_subtree(node, <<>>), do: node

  defp get_subtree(@empty_branch, _loc, _depth), do: @empty_branch
  defp get_subtree({_, _} = leaf, _loc, _depth), do: leaf
  defp get_subtree(_node, loc, 0), do: {:partial, loc}

  defp get_subtree({h, b_l, b_r}, loc, depth) do
    {h, get_subtree(b_l, <<loc::bits, 0::size(1)>>, depth - 1),
     get_subtree(b_r, <<loc::bits, 1::size(1)>>, depth - 1)}
  end

  def max_depth(_, depth \\ 0)
  def max_depth(@empty_branch, depth), do: depth
  def max_depth({_, _}, depth), do: depth

  def max_depth({_, b_l, b_r}, depth) do
    Enum.max([max_depth(b_l, depth + 1), max_depth(b_r, depth + 1)])
  end

  defp raw_keys(@empty_branch), do: []
  defp raw_keys({_, b_l, b_r}), do: [raw_keys(b_l), raw_keys(b_r)]
  defp raw_keys({_, {_, contents}}), do: Map.keys(contents) |> add_tuple_wrappers()
  defp raw_keys({:partial, loc}), do: [{:partial, loc}] |> add_tuple_wrappers

  def calculate_hashes(tree) do
    {_, new_tree} = do_calculate_hashes(tree)
    new_tree
  end

  defp do_calculate_hashes(@empty_branch), do: {@empty_hash, @empty_branch}

  defp do_calculate_hashes({@empty_hash, b_l, b_r}) do
    {hash_l, b_l} = do_calculate_hashes(b_l)
    {hash_r, b_r} = do_calculate_hashes(b_r)
    total_hash = hash({hash_l, hash_r})
    {total_hash, {total_hash, b_l, b_r}}
  end

  defp do_calculate_hashes({hash, _, _} = inner_node), do: {hash, inner_node}

  defp do_calculate_hashes({@empty_hash, {hash_key, contents}}) do
    c_hash = hash(contents)
    new_leaf = {c_hash, {hash_key, contents}}
    {c_hash, new_leaf}
  end

  defp do_calculate_hashes({hash, _} = leaf) do
    {hash, leaf}
  end

  defp hash(x) do
    <<:erlang.phash2(x, @hash_limit)::size(@max_levels)>>
  end

  defp add_tuple_wrappers(keys, wrapped_keys \\ [])
  defp add_tuple_wrappers([], wrapped), do: wrapped

  defp add_tuple_wrappers([key | keys], wrapped) do
    add_tuple_wrappers(keys, [{key} | wrapped])
  end

  defp remove_tuple_wrappers(keys, unwrapped_keys \\ [])
  defp remove_tuple_wrappers([], unwrapped), do: unwrapped

  defp remove_tuple_wrappers([{key} | keys], unwrapped) do
    remove_tuple_wrappers(keys, [key | unwrapped])
  end
end
