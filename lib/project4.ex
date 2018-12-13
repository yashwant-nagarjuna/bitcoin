defmodule Project4 do
  @moduledoc """
  Documentation for Project4.
  """

  @doc """
  Hello world.
  """
  use GenServer

  defmodule Transaction do
    defstruct from: "0", to: "", amount: "", timestamp: "", signature: "" 
  end

  defmodule Block do
    defstruct list: [], prev_hash: "", timestamp: "random hash", this_hash: "", nonce: ""
  end

  # defmodule Wallet do
  #   defstruct transac_hist: nil, my_money: nil
  # end

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    {:ok, {[], 0, [],[],0,0}} # wallet, neighbors, blockChain, pending transaction
  end

  # main function
  def main(args) do
    # numNodes = Enum.at(args, 0) |> String.to_integer()
    numNodes = args
    # numRequests = Enum.at(args, 1) |>String.to_integer()
    pids = createNodes(numNodes)
    table = createTable(pids)
    createFullNW(table,pids)
    block_chain = create_block_chain()
    createGenesisBlock(table,block_chain)
    start_bitcoin(pids,table,block_chain,100)
    # start_transaction()
  end

  def start_bitcoin(pids,table,block_chain,iterator) do
    if iterator > 0 do 
      # a = Enum.random(pids)
      # b = Enum.random(List.delete(pids,a))
      # create_transaction(a,b,Enum.random(10..100))
      # user_1 = Kernel.inspect(a)
      # user_2 = Kernel.inspect(b)
      # IO.puts "before...."
      # IO.puts "user 1 balance : #{get_acc_balance(getID(a),block_chain)}"
      # IO.puts "user 2 balance : #{get_acc_balance(getID(b),block_chain)}"
      create_transaction(pids,block_chain,Enum.random(1..50))
      mine_transactions(block_chain,pids)
      IO.inspect iterator
      IO.inspect is_BlockChain_valid(block_chain)
      # IO.puts "after..."
      # IO.puts "user 1 balance : #{get_acc_balance(getID(a),block_chain)}"
      # IO.puts "user 2 balance : #{get_acc_balance(getID(b),block_chain)}"
      start_bitcoin(pids,table,block_chain,iterator-1)
    end
  end

  def create_transaction(pids,block_chain,times) do
    if times > 0 do
      p1 = Enum.random(pids)
      p2 = Enum.random(List.delete(pids,p1))
      a= getID(p1)
      b= getID(p2)
      amt = Enum.random(5..50)
      transac = %Transaction{from: a, to: b, amount: amt , timestamp: to_string(DateTime.utc_now())}
      message = transaction_hash(transac)
      sign = digital_signature(message,getPrivKey(p1))
      transac = %{transac | signature: sign}
      add_transaction(transac,block_chain)
      create_transaction(pids,block_chain,times-1)
    end
  end

  def createNodes(numNodes) do
    Enum.map((1..numNodes), fn _x ->
      {:ok, pid} = start_link()
      # IO.inspect pid
      {:ok, priv} = RsaEx.generate_private_key
      {:ok, pub} = RsaEx.generate_public_key(priv)
      # IO.inspect priv
      set_state(pid,priv,pub)
      pid
    end)
  end

  # creating a table mapping all keys to the pids
  def createTable(pids) do
    ids = Enum.map(pids, fn x ->
      getID(x)
    end)
    table = Enum.zip(ids, pids)
    # IO.inspect table
    table
  end

  def createFullNW(table,nodes) do
    neighbour_list = table
    Enum.each(nodes, fn x ->
      list = neighbour_list
      GenServer.call(x, {:pass_list, list})
    end)
  end

  def mine_transactions(block_chain,pids) do
    list = get_pending_transac(block_chain)
    Enum.each(pids, fn x ->
    GenServer.cast(x,{:mine,[list,block_chain,x]})
    end)
  end

  def get_pending_transac(block_chain) do
    GenServer.call(block_chain,{:getPendingTransacs})
  end

  def transaction_hash(transaction) do
    data_string = transaction.from <> transaction.to <> to_string(transaction.amount)<> transaction.timestamp
    transaction_hash = :crypto.hash(:sha256, data_string) |> Base.encode16
    transaction_hash
  end

  def digital_signature(message, private_key) do
    {:ok, signature} = RsaEx.sign(message, private_key)
    signature
  end

  def verify_signature(message, signature, public_key) do
    {:ok, valid} = RsaEx.verify(message, signature, public_key)
    valid
  end

  def create_block(list,block_chain,nodeID,pub) do 
    curr_list = Enum.reduce(list,[], fn x,acc ->
      if is_transac_valid(x,block_chain) do
        acc ++ [x] 
      end
    end)
    transac_list = 
      if curr_list == nil do
        []
      else
        curr_list
      end
    last_block = get_last_block(block_chain)
    new_transac = %Transaction{from: "0", to: pub, amount: Enum.random(3..5) , timestamp: to_string(DateTime.utc_now())}
    new_list = transac_list ++ [new_transac]
    thisBlock = %Block{timestamp: DateTime.utc_now(),list: new_list, prev_hash: last_block.this_hash}
    hash  = gen_hash(thisBlock)
    [result , answer] = hashGen(hash ,5)
    thisBlock = %{thisBlock | nonce: answer, this_hash: result}
    if transac_list != [] do
      if is_block_valid(thisBlock,block_chain) do
        add_block(block_chain, thisBlock)
      end
    end
  end


 

  def gen_hash(block) do
    transac_list= block.list
    list = Enum.reduce(transac_list,"", fn x,acc ->
    acc <> x.from<>x.to<>to_string(x.amount)
    end )
    data = list <> to_string(block.timestamp) <> block.prev_hash
    hash = :crypto.hash(:sha256,data)|>Base.encode16()
    hash
  end

  def is_block_valid(block,block_chain) do
    transac_list = block.list
    is_valid = Enum.reduce(transac_list, true, fn x,acc ->
      if x.from == "0" do
        true
      else
        acc and verify_signature(transaction_hash(x),x.signature,x.from)
      end
    end)
    last_block = get_last_block(block_chain)
    hash = gen_hash(block)
    check =
      if block.this_hash == :crypto.hash(:sha256,hash<>block.nonce)|>Base.encode16() and block.prev_hash == last_block.this_hash do
        is_valid
      else
        false
      end
    check
  end

  def is_BlockChain_valid(block_chain) do
    chain = get_blocks(block_chain)
    check = Enum.reduce(chain, true , fn  x,acc ->
      if x.prev_hash == "0" do
        acc and true
      else 
        if x.prev_hash == Enum.at(chain,Enum.find_index(chain,fn y -> y==x end)-1).this_hash do
          acc and true and Enum.reduce(x.list, true, fn z,acc ->
            if z.from == "0" do
              true
            else
              acc and verify_signature(transaction_hash(z),z.signature,z.from)
            end
        end)
        else
          false
        end
      end
    end)
    check
  end 

  def isBlockValid(block,block_chain) do
    transac_list = block.list
    is_valid = Enum.reduce(transac_list, true, fn x,acc ->
      if x.from == "0" do
        true
      else
        acc and verify_signature(transaction_hash(x),x.signature,x.from)
      end
    end)
    last_block = get_second_last_block(block_chain)
    hash = gen_hash(block)
    check =
      if block.this_hash == :crypto.hash(:sha256,hash<>block.nonce)|>Base.encode16() and block.prev_hash == last_block.this_hash do
        is_valid
      else
        false
      end
    check
  end

  def hashGen(s,len) do
    answer = Enum.take_random(?0..?z,len)|>to_string
    genString = s <> answer
    hash = :crypto.hash(:sha256,genString)|>Base.encode16
    if String.slice(hash,0,3) != "000" do
      hashGen(s,len)
    else
      [hash,answer]
    end
  end



  def createGenesisBlock(table, block_chain) do
    initial_list = Enum.map(table, fn x ->
      {pub_key,_pid} = x
      # IO.inspect pid
      transac =  %Transaction{from: "0" , to: pub_key, amount: 1000, timestamp: to_string(DateTime.utc_now())}
      transac
      # IO.inspect transac
    end)
    genesis_block = %Block{timestamp: DateTime.utc_now(),list: initial_list, prev_hash: "0", nonce: "00000000000000"}
    # hash = gen_hash(genesis_block)
    genesis_block = %{genesis_block | this_hash: "000000000000000"}
    # IO.inspect genesis_block
    block= genesis_block
    GenServer.call(block_chain,{:addBlock,block})
    Enum.each(table, fn x ->
      {_pub_key,pid} = x
      GenServer.call(pid,{:addnewBlock,block})
    end)
    # IO.inspect genesis_block
  end

  def get_acc_balance(node,block_chain) do
    blocks = get_blocks(block_chain)
    acc_balance = Enum.reduce(blocks,0.0, fn x,acc ->
    acc + get_block_balance(x,node)
    end)
    acc_balance
  end

  def get_blocks(block_chain) do
    GenServer.call(block_chain, {:getChain})
  end

  def get_block_balance(block,pub_key) do
    transac_list  = block.list
    block_balance = Enum.reduce(transac_list, 0.0, fn x, acc->
      from = x.from
      to = x.to
      amount = x.amount
      cond do
        from == pub_key ->
          acc - amount
        to == pub_key ->
          acc + amount
        true ->
          acc
      end
    end)
    block_balance
  end

  def getBlockBalance(block) do
    transac_list  = block.list
    block_balance = Enum.reduce(transac_list, 0, fn x, acc->
      amt = x.amount
      # if x.from != "0" do
      acc + amt
    end)
    block_balance
  end

  def is_transac_valid(transac,block_chain) do
    if transac.from == "0" do
        true
    else
      if get_acc_balance(transac.from,block_chain) >= transac.amount and verify_signature(transaction_hash(transac),transac.signature,transac.from) do
        true
      else
        # IO.puts "Invalid Transaction"
        false
      end  
    end
  end

  def create_block_chain do
    {:ok,pid} = start_link()
    pid
  end

  def add_block(block_chain,block) do
    GenServer.call(block_chain,{:addBlock,block})
  end

  def add_transaction(transac,block_chain)  do
      GenServer.call(block_chain,{:addTransac,transac})
  end

  def get_last_block(block_chain) do
    last_block= GenServer.call(block_chain, {:getlastblock})
    last_block
  end

  def get_second_last_block(block_chain) do
    last_second = GenServer.call(block_chain, {:getSecondLastBlock})
    last_second
  end

  def getPrivKey(node) do
    GenServer.call(node,{:getprivateK})
  end

  def getPubKey(node) do
    GenServer.call(node, {:getpublicK})
  end

  def set_state(pid,priv,pub) do
    GenServer.call(pid, {:setState, {pub,priv}})
  end

  def getID(pid) do
    GenServer.call(pid, {:getID})
  end

  def handle_call({:addBlock,block}, _from, state) do
    {chain ,difficulty, pending_transactions, g1, g2, g3} = state
    last_block = Enum.at(chain,-1)
    new_chain =
      if block.prev_hash == "0" or block.prev_hash == last_block.this_hash do
        curr_time = DateTime.utc_now()
        rew_transac = Enum.find(block.list, fn x-> x.from == "0" end)
        reward = rew_transac.amount
        amount_transacted = getBlockBalance(block)
        diff = DateTime.diff(curr_time,block.timestamp, :millisecond)
        node = %{value: length(block.list), time_taken: diff , transacted_amt: amount_transacted, rew: reward}
        IO.inspect node
        BitcoinWeb.Endpoint.broadcast!("room:lobby", "new_message", node)
        chain ++ [block]
      else
        chain
      end 
    state = {new_chain ,difficulty, pending_transactions, g1, g2, g3}
    # IO.inspect state
    {:reply, new_chain, state}
  end

 def handle_call({:addnewBlock,block}, _from, state) do
    {pub_key,priv_key,neighbors,chain,curr_block,wallet} = state
    new_chain = chain ++ [block]
    state = {pub_key,priv_key,neighbors,new_chain,curr_block,wallet}
    # IO.inspect state
    {:reply, new_chain, state}
  end

  def handle_call({:addTransac,transac}, _from, state) do
    {chain ,difficulty, pending_transactions, g1, g2, g3} = state
    new_transactions = pending_transactions ++ [transac]
    state = {chain ,difficulty, new_transactions, g1, g2, g3}
    {:reply, new_transactions, state}
  end
  
  def handle_call({:getPendingTransacs},_from,state) do
    {chain,difficulty,pending_transactions,g1,g2,g3} = state
    # if pending_transactions == [] do
    #   System.halt(1)
    # end
    list= pending_transactions
    new_pending = []
    state = {chain,difficulty,new_pending,g1,g2,g3} 
    {:reply,list,state}
  end 

  def handle_call({:getlastblock},_from, state) do
    {chain,_,_,_,_,_} = state
    last_block = List.last(chain)
    # IO.inspect state
    {:reply,last_block, state}
  end

  def handle_call({:getSecondLastBlock}, _from, state) do
    {chain, _, _, _, _, _} = state
    last_second = Enum.at(chain, -2)
    {:reply, last_second, state}
  end

  def handle_call({:pass_list, list}, _from, state) do
   {nodeID, count, _, cuur_block, blockChain, wallet} = state
   state = {nodeID, count, list,cuur_block, blockChain, wallet}
   # IO.inspect list
   {:reply, list, state}
  end

  def handle_call({:getChain}, _from, state) do
    {a, _, _, _, _, _} = state
    {:reply, a, state}
  end

  def handle_call({:setState, {pub,priv}}, _from, state) do
    {_, _, neighbors, curr_block, block_chain, _} = state
    wallet ={pub,priv} 
    state = {pub, priv, neighbors, curr_block, block_chain, wallet}
    # IO.inspect state
    {:reply, {pub,priv}, state}
  end

  def handle_call({:getprivateK}, _from, state) do
    {_, _, _, _, _, wallet} = state
    {_,priv} = wallet
    {:reply, priv, state}
  end

  def handle_call({:getpublicK}, _from, state) do
    {_, _, _, _, _, wallet} = state
    {pub,_} = wallet
    {:reply, pub, state}
  end

  def handle_call({:getID}, _from, state) do
    {_, _, _, _, _, wallet} = state
    {pub,_} = wallet
    {:reply, pub, state}
  end

  def handle_cast({:mine,[list,block_chain,x]},state) do
    {a,b,c,d,e,f} = state
    create_block(list,block_chain,x,a)  
    state = {a,b,c,d,e,f}
    {:noreply,state}
  end

end

# Project4.main(System.argv())
