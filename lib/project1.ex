defmodule Project1 do

    #Main method to run the code from escript.build. 
    #If the argument is an ip address it will call the 'startClientNode' 
    #Else it will call startServerNode function. 
    def main(args \\ []) do
        {check,_}=:inet_parse.strict_address('#{args}')
        {n, _} =  :string.to_integer(to_charlist(args))
        #IO.puts check
        case check do
          :error->startServerNode(n)
          :ok->startClientNode(to_string(args))
        end
    end

    #Spawns a process to start the server node as well as spawns multiple
    #processes to mine the bitcoins    
    def startServerNode(n) do
        spawn(fn-> Project1.startNode(n) end)  
        Enum.each(1..7, fn(i)-> spawn(fn-> serverMining(n) end) end)
        spawn(serverMining(n))

    end

    #Start the server node
    def startNode(n) do
        IO.puts "Inside startNode"
        {:ok,[{ip1,_,_}|tail]}=:inet.getif()
        localIp = List.to_string(:inet_parse.ntoa(ip1))
        IO.puts localIp
        unless Node.alive?() do
        {:ok, _} = Node.start(String.to_atom("server@"<>localIp))
        end
        cookie = Application.get_env(String.to_atom("server@"<>localIp) , :cookie)
        Node.set_cookie(cookie)
        #:global.register_name(:server, self())
        IO.puts "Node started"
        :ets.new(:count_registry, [:named_table])
        :ets.insert(:count_registry, {"List", length(Node.list)})
        waitForConnection(n)
    end

    #Recursively looks for connecting workers and distribute mining 
    #jobs as soon as workers are connected to the server
    def waitForConnection(n) do
        if (length(Node.list) != 0) do
          [{_,test}]=:ets.lookup(:count_registry, "List")
          IO.puts test
          if(test != length(Node.list)) do
             workerIp = List.last(Node.list)
          end
          distributeWork(workerIp,n)
          :ets.insert(:count_registry, {"List", length(Node.list)})
 
          waitForConnection(n)
        else
          waitForConnection(n)
        end 
    end

    #Distrbutes the mining jobs to the worker node.
    def distributeWork(workerNodeName,n) do
        pids = Enum.map(1..8,fn(_) -> Node.spawn(workerNodeName,Project1,:workerMining,[n])end)
        listen()
    end

    #To stop worker nodes  when server node goes down
    def listen do
            if !Node.alive?() do
                Node.stop()
            else 
                listen()
            end
    end

    #Starts the worker node 
    def startClientNode(serverIp) do
        IO.puts "Serverip:"<>serverIp
        {:ok,[{ip,_,_}|tail]}=:inet.getif()
        workerIp = List.to_string(:inet_parse.ntoa(ip))
        IO.puts "workerIp:"<>workerIp
        unless Node.alive?() do
        {:ok, _} = Node.start(String.to_atom("worker@"<>workerIp))
        end
        cookie = Application.get_env(String.to_atom("worker@"<>workerIp) , :cookie)
        Node.set_cookie(cookie)
        IO.puts Node.self()
        IO.puts "Inside CLient"
        startConnection("server@"<>serverIp)
    end

    #Worker node establishes connection with the server
    def startConnection(serverNodeName) do
        IO.puts "Inside Server"
        IO.puts serverNodeName
        Node.connect(String.to_atom(serverNodeName))
        :timer.sleep(:infinity)
        IO.puts  "Connection done"

    end

    #Mines the bitcoins for server machine 
    def serverMining(n) do
        input = :crypto.strong_rand_bytes(8) |> Base.url_encode64 |> binary_part(0,8)
        finalstring = "rameshwari.oblar;"<>input
        hashedOutput = :crypto.hash(:sha256,finalstring) |> Base.encode16 |> String.downcase
        checkString = "" |> String.pad_leading(n,"0")
        temp = (checkString == String.slice(hashedOutput,0,n))
        if temp==true do
            IO.puts finalstring<>" "<> hashedOutput
        end
        serverMining(n)      
    end 

    #Mines the bitcoins for worker machine 
    def workerMining(n) do
        i = Enum.random(9..16)
        input = :crypto.strong_rand_bytes(i) |> Base.url_encode64 |> binary_part(0,i)
        finalstring = "rameshwari.oblar;"<>input
        hashedOutput = :crypto.hash(:sha256,finalstring) |> Base.encode16 |> String.downcase
        checkString = "" |> String.pad_leading(n,"0")
        temp = (checkString == String.slice(hashedOutput,0,n))
        if temp==true do
            IO.puts finalstring<>" "<> hashedOutput
        end
        workerMining(n) 
    end
end