%%%-------------------------------------------------------------------
%%% @author Naor Dahan
%%% @copyright (C) 2019, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 03. אוג׳ 2019 09:36
%%%-------------------------------------------------------------------
-module(garden).
-author("Naor Dahan").

-behaviour(gen_server).
-include("globalVariables.hrl").

%% API
-export([test/0, init/1, handle_cast/2, handle_call/3]).
-export([start_link/3,terminate/2,createFlowers/0]).
-record(state, {}).

%TODO check if need more msg from/to flower and main server
%TODO who create the flowers?

%%Creates a gen_server process as part of a supervision tree.
%%start_link(ServerName, Module, Args, Options) -> Result
start_link(GlobalName, Number, MainServerGlobalName) ->
  io:fwrite("garden: start_link: Number = ~p ~n",[Number]),
  gen_server:start_link({global,GlobalName}, ?MODULE, [MainServerGlobalName,Number], []).

%%A set or ordered_set table can only have one object associated with each key
%%When the process terminates, the table is automatically destroyed
%%Notice that there is no automatic garbage collection for tables
%% To destroy a table explicitly, use function delete/1.
%%The table is a set table: one key, one object, no order among objects
init([MainServerGlobalName,Number]) ->
  put(myNumber, Number),
  io:fwrite("garden: init: Number = ~p ~n",[Number]),
  put(server,{global,MainServerGlobalName}),
  ets:new(flowers,[set,named_table,public]),
  %TODO Status = gen_server:call(get(server),{connect,node()}),
 % io:fwrite("garden: init: Status = ~p ~n",[Status]), %TODO for test
  {ok, #state{}}.

%From MainServer
handle_cast(addFlower, NewState) ->
  createFlowers(),
  {noreply, NewState};

%From MainServer
handle_cast({sendGardenerToFlower, Gardener, Flower}, NewState) ->
  sendGardenerToFlower(Gardener, Flower),
  {noreply, NewState};

%From Flower
handle_cast({updateFlower,Flower}, NewState) -> %TODO one msg to all status changes?
  gen_server:cast(get(server),{updateFlower,Flower}),%Send to main server updateFlowerStatus
  {noreply, NewState};

handle_cast({changeFlowerStatus,Flower}, NewState) -> %TODO one msg to all status changes?
  gen_server:cast(get(server),{changeFlowerStatus,Flower}),%Send to main server updateFlowerStatus
  {noreply, NewState};


%From Flower
handle_cast({flowerDie,Flower=#flower{id = Id, gardenerID = none}}, NewState) ->
  gen_server:cast(get(server), {deleteFlower, Flower}),%Send to main server delete flower
  {noreply, NewState};

%From Flower
handle_cast({flowerDie,Flower=#flower{id = Id, gardenerID = GardenerId}}, NewState) ->
  gen_server:cast({global,GardenerId},cancelWalk),
  gen_server:cast(get(server), {deleteFlower,Flower}),%Send to main server delete flower
  {noreply, NewState};

%From gardener
handle_cast({gardenerHandleFlower,Gardener}, NewState) ->
  gen_server:cast(get(server),{gardenerHandleFlower,Gardener}),
  {noreply, NewState};

%From gardener
handle_cast({gardenerWalkToFlower,Gardener}, NewState) ->
  gen_server:cast(get(server),{gardenerWalkToFlower,Gardener}),
  {noreply, NewState};

%From gardener
handle_cast({changeGardenerGarden,Gardener}, NewState) ->
  gen_server:cast(get(server),{changeGardenerGarden,Gardener}),
  {noreply, NewState};

%From gardener
handle_cast({gardenerResting,Gardener}, NewState) ->
  io:fwrite("garden: gardenerResting: Gardener = ~p ~n",[Gardener]),

  gen_server:cast(get(server),{gardenerResting,Gardener}),
  {noreply, NewState};

%From gardener
handle_cast({changeGardenerLocation, {OldX, OldY, Gardener}}, NewState) ->
  io:fwrite("garden: changeGardenerLocation: Gardener = ~p ~n",[Gardener]),

  gen_server:cast(get(server),{changeGardenerLocation,{OldX, OldY, Gardener}}),
  {noreply, NewState}.

handle_call(Request,From,State)->
  {Request,From,State}.

terminate(Reason, State) -> %TODO complete
  {Reason, State}.

% Send msg to gardner and flower
sendGardenerToFlower(Gardener, Flower) ->
  FlowerId = Flower#flower.id,
  FlowerLocation = {Flower#flower.x, Flower#flower.y},
  gen_server:cast({global,Gardener#gardener.id},{walkToFlower, FlowerId, get(myNumber), FlowerLocation}), %send to gardener
  FlowerId ! {setGardenerID,Gardener#gardener.id}. %send to flower

createFlowers() ->
  Flower = #flower{id = a, type = getRandomFlower(), status=normal, timeSinceProblem = 0, gardenerID = none, gardenID = 1, x = 880, y = 400 },
  io:fwrite("createFlower ,Flower~p ~n",[Flower]),
  gen_server:cast({global,?masterServerName},{newFlower,Flower}),
  timer:sleep(3000),
  register(a, spawn(flower, flowerAsStateMachine, [Flower])).

getRandomFlower()->
  RandomFlower = getRandomNumber(40),
  if
    RandomFlower < 10 -> iris_l;
    RandomFlower < 20 -> iris_r;
    RandomFlower < 30 -> red_l;
    true -> red_r
  end.

getRandomNumber(Gap)->
  {T1,T2,T3} = now(),
  random:seed(T1, T2, T3),
  random:uniform(Gap).

test() ->
  gen_server:cast({global,garden1},{addFlower,10}).