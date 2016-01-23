% File : usr.erl
% Des : API and gen_serer code for cellphone user db

-module(usr).
-export([start_link/0, start_link/1, stop/0]).
-export([init/1, terminate/2, handle_call/3, handle_cast/2, handle_info/2]).
-export([add_usr/3, delete_usr/1, set_service/3, set_status/2, 
  delete_disabled/0, lookup_id/1]).
-export([lookup_msisdn/1, service_flag/2]).

-behavior(gen_server).

-include("../include/usr.hrl").

% Exported client functions
% operatin & maintenance API

start_link() -> 
  {ok, Filename} = application:get_env(dets_name),
  start_link(Filename).

start_link(Filename) ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, Filename, []).

stop() -> gen_server:cast(?MODULE, stop).

%% custom services api

add_usr(PhoneNo, CustId, Plan) when Plan == prepay; Plan == postpay -> 
  io:format("~w, ~w, ~w~n", [PhoneNo, CustId, Plan]),
  gen_server:call(?MODULE, {add_usr, PhoneNo, CustId, Plan}).

delete_usr(CustId) ->
  gen_server:call(?MODULE, {delete_usr, CustId}).

set_service(CustId, Service, Flag) when Flag == true; Flag == false ->
  gen_server:call(?MODULE, {set_service, CustId, Service, Flag}).

set_status(CustId, Status) when Status == enabled; Status == disabled ->
  gen_server:call(?MODULE, {set_status, CustId, Status}).

delete_disabled() ->
  gen_server:call(?MODULE, delete_disabled).

lookup_id(CustId) -> usr_db:lookup_id(CustId).

% Server API
lookup_msisdn(PhoneNo) -> usr_db:lookup_msisdn(PhoneNo).

service_flag(PhoneNo, Service) -> 
  case usr_db:lookup_msisdn(PhoneNo) of 
    {ok, #usr{services=Services, status=enabled}} ->
      lists:member(Service, Services);
    {ok, #usr{status=disabled}} -> {error, disabled};
    {error, Reason} -> {error, Reason}
  end.

%% Callback ftn.
init(Filename) ->
  usr_db:create_tables(Filename),
  usr_db:restore_backup(),
  {ok, null}.

terminate(_Reason, _LoopData) ->
  usr_db:close_tables().

handle_cast(stop, LoopData) -> {stop, normal, LoopData}.

handle_call({add_usr, PhoneNo, CustId, Plan}, _From, LoopData) ->
  io:format("add_usr handle_call : ~w~n", [PhoneNo]),
  Reply = usr_db:add_usr(#usr{msisdn=PhoneNo, id=CustId, plan=Plan}),
  %% 약 3시간 동안 replay라고 쓴것을 모르고 있었다. 
  %% 결국 함수의 문제가 아니라. return값이 잘못되었다는 것이군. 
  %% {replay, Reply, LoopData};
  {reply, Reply, LoopData};

handle_call({delete_usr, CustId}, _From, LoopData) ->
  Reply = usr_db:delete_usr(CustId), 
  {reply, Reply, LoopData};

handle_call({set_service, CustId, Service, Flag}, _From, LoopData) ->
  Reply = case usr_db:lookup_id(CustId) of
    {ok, Usr} ->
      Services = lists:delete(Service, Usr#usr.services), 
      NewServices = case Flag of 
        true -> [Service|Services];
        false -> Services
      end,
      usr_db:update_usr(Usr#usr{services=NewServices});
    {error, instance} -> {error, instance}
  end,
  {reply, Reply, LoopData};

handle_call({set_status, CustId, Status}, _From, LoopData) ->
  Reply = case usr_db:lookup_id(CustId) of
    {ok, Usr} -> usr_db:update_usr(Usr#usr{status=Status});
    {error, instance} -> {error, instance}
  end,
  {reply, Reply, LoopData};

handle_call(delete_disabled, _From, LoopData) ->
  {reply, usr_db:delete_disabled(), LoopData}.

% 알지 못하는 메시지 처리를 위해서 
handle_info(_Msg, LoopData) -> {noreply, LoopData}.

