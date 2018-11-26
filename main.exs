# args = System.argv()
# numNodes = String.to_integer(Enum.at(args, 0))
# numRequests = String.to_integer(Enum.at(args, 1))

#start_time = System.monotonic_time(:millisecond)
#ExUnit.start()
Mitbits.Application.start(:normal)
