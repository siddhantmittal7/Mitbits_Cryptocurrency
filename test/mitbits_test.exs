defmodule MitbitsTest do
  use ExUnit.Case
  #doctest Mitbits

  import ExUnit.CaptureLog
  require Logger

  #test "greets the world" do
    #assert Mitbits.hello() == :world
  #end

  Mitbits.Application.start(:normal)


  test "the truth" do
    assert 1+1 == 1
  end

  test "Create 100 txn between any two participanta" do


    Mitbits.Driver.make_transactions()
    assert 1+1 == 1
  end

  #test "Running the application the application to create genesis block" do
    #assert capture_log(Mitbits.Application.start(:normal))
  #end
end
