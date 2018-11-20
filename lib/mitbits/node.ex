defmodule Chord.Node do
  use GenServer

  # API
  def start_link({node_id, m}) do
    GenServer.start_link(__MODULE__, m, name: :"node_#{node_id}")
  end

  def create_chord_ring(new_node, fake_node) do
    GenServer.call(:"node_#{new_node}", {:create, new_node, fake_node})
  end

  def join_new_node(new_node, existing_node) do
    GenServer.call(:"node_#{new_node}", {:join, new_node, existing_node})
  end

  # Server
  def init(m) do
    {:ok, {0, 0, %{}, m}}
  end

  def handle_call(:get_predecessor, _from, {self_node_id, predecessor, finger_table, m}) do
    {:reply, predecessor, {self_node_id, predecessor, finger_table, m}}
  end

  def handle_call(:get_successor, _from, {self_node_id, predecessor, finger_table, m}) do
    {:reply, Map.get(finger_table, 0), {self_node_id, predecessor, finger_table, m}}
  end

  def handle_call(:get_finger_table, _from, {self_node_id, predecessor, finger_table, m}) do
    {:reply, finger_table, {self_node_id, predecessor, finger_table, m}}
  end

  def handle_call(
        {:create_fake, first_node, fake_node},
        _from,
        {self_node_id, predecessor, finger_table, m}
      ) do
    predecessor = first_node
    self_node_id = fake_node
    finger_table = Map.put(finger_table, 0, first_node)
    {:reply, {:ok}, {self_node_id, predecessor, finger_table, m}}
  end

  def handle_call(
        {:create, first_node, fake_node},
        _from,
        {self_node_id, predecessor, finger_table, m}
      ) do
    predecessor = fake_node
    self_node_id = first_node
    finger_table = Map.put(finger_table, 0, fake_node)
    {:ok} = GenServer.call(:"node_#{fake_node}", {:create_fake, first_node, fake_node})
    {:reply, {:ok}, {self_node_id, predecessor, finger_table, m}}
  end

  def handle_call(
        {:notify, possible_predecessor},
        _from,
        {self_node_id, predecessor, finger_table, m}
      ) do
    predecessor =
      if(
        predecessor == nil ||
          (possible_predecessor > predecessor && possible_predecessor < self_node_id) ||
          (predecessor > self_node_id && possible_predecessor < predecessor)
      ) do
        possible_predecessor
      else
        predecessor
      end

    {:reply, {:ok}, {self_node_id, predecessor, finger_table, m}}
  end

  def handle_cast(:stabilize, {self_node_id, predecessor, finger_table, m}) do
    successor = Map.get(finger_table, 0)
    x = GenServer.call(:"node_#{successor}", :get_predecessor)

    if(x != self_node_id) do
      successor =
        if((x > self_node_id && x < successor) || (self_node_id > successor && x < successor)) do
          x
        else
          successor
        end

      {:ok} = GenServer.call(:"node_#{successor}", {:notify, self_node_id})
      {_, finger_table} = Map.get_and_update(finger_table, 0, fn x -> {x, successor} end)
      {:noreply, {self_node_id, predecessor, finger_table, m}}
    else
      {:noreply, {self_node_id, predecessor, finger_table, m}}
    end
  end

  def handle_call(
        {:join, new_node, existing_node},
        _from,
        {self_node_id, predecessor, finger_table, m}
      ) do
    self_node_id = new_node
    successor = GenServer.call(:"node_#{existing_node}", {:find_successor, self_node_id})
    finger_table = Map.put_new(finger_table, 0, successor)
    predecessor = nil
    {:ok} = GenServer.call(:"node_#{successor}", {:notify, self_node_id})
    {:reply, {:ok}, {self_node_id, predecessor, finger_table, m}}
  end

  defp closest_preceding_node(key, finger_table, self_node_id) do
    keys = Map.keys(finger_table)
    size_of_table = Enum.count(keys)
    prec_node = closest_preceding_node_helper(size_of_table, finger_table, key, self_node_id)
  end

  defp closest_preceding_node_helper(size_of_table, finger_table, key, self_node_id) do
    if(size_of_table == 0) do
      Map.get(finger_table, 0)
    else
      table_entry = Map.get(finger_table, size_of_table - 1)

      if((table_entry > self_node_id && table_entry < key) || key < self_node_id) do
        table_entry
      else
        closest_preceding_node_helper(size_of_table - 1, finger_table, key, self_node_id)
      end
    end
  end

  def handle_call({:find_successor, key}, _from, {self_node_id, predecessor, finger_table, m}) do
    successor = Map.get(finger_table, 0)

    successor_for_key =
      if(
        (key > self_node_id && key <= successor) || (self_node_id > successor && key <= successor)
      ) do
        successor
      else
        n_dash = closest_preceding_node(key, finger_table, self_node_id)
        GenServer.call(:"node_#{n_dash}", {:find_successor, key})
      end

    {:reply, successor_for_key, {self_node_id, predecessor, finger_table, m}}
  end

  def handle_cast(
        {:find_successor_lookup, {key, hops}},
        {self_node_id, predecessor, finger_table, m}
      ) do
    successor = Map.get(finger_table, 0)

    if(
      (key > self_node_id && key <= successor) || (self_node_id > successor && key <= successor)
    ) do
      [{_, req_count}] = :ets.lookup(:chord, "req_count")
      req_count = req_count - 1
      :ets.insert(:chord, {"req_count", req_count})
    else
      n_dash = closest_preceding_node(key, finger_table, self_node_id)
      [{_, hops_count}] = :ets.lookup(:chord, "hops_count")
      hops_count = hops_count + 1
      :ets.insert(:chord, {"hops_count", hops_count})
      GenServer.cast(:"node_#{n_dash}", {:find_successor_lookup, {key, hops + 1}})
    end

    {:noreply, {self_node_id, predecessor, finger_table, m}}
  end

  defp find_successor_func(finger_table, key, self_node_id) do
    successor = Map.get(finger_table, 0)

    successor_for_key =
      if(
        (key > self_node_id && key <= successor) || (self_node_id > successor && key < successor)
      ) do
        successor
      else
        n_dash = closest_preceding_node(key, finger_table, self_node_id)
        GenServer.call(:"node_#{n_dash}", {:find_successor, key})
      end
  end

  def fix_fingers_helper(i, finger_table, self_node_id, m, predecessor) do
    if(i > m) do
      finger_table
    else
      key = self_node_id + :math.pow(2, i - 1)
      succ = find_successor_func(finger_table, key, self_node_id)

      {_, finger_table} =
        if(Map.has_key?(finger_table, i - 1) == true) do
          Map.get_and_update(finger_table, i - 1, fn curr -> {curr, succ} end)
        else
          {1, finger_table}
        end

      finger_table =
        if(Map.has_key?(finger_table, i - 1) == false) do
          Map.put_new(finger_table, i - 1, succ)
        else
          finger_table
        end

      fix_fingers_helper(i + 1, finger_table, self_node_id, m, predecessor)
    end
  end

  def handle_cast(:fix_fingers, {self_node_id, predecessor, finger_table, m}) do
    if(self_node_id != @max) do
      finger_table = fix_fingers_helper(1, finger_table, self_node_id, m, predecessor)
      {:noreply, {self_node_id, predecessor, finger_table, m}}
    else
      {:noreply, {self_node_id, predecessor, finger_table, m}}
    end
  end
end

