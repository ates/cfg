-module(cfg).

-behaviour(application).
-behaviour(supervisor).

-export([start/2]).
-export([stop/1]).

-export([start_link/0]).
-export([init/1]).

-export([env/1]).
-export([env/2]).
-export([reload/0]).

start(_StartType, _StartArgs) -> start_link().
stop(_State) -> ok.

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    reload(),
    {ok, {{one_for_all, 1, 1}, []}}.

env(Option) ->
    env(Option, undefined).

env([Option | Rest], Default) ->
    case persistent_term:get({?MODULE, Option}, undefined) of
        Value when Rest =:= [] -> Value;
        Value when is_map(Value) ->
            env(Rest, Value, Default);
        _Value -> Default
    end;

env(Option, Default) ->
    persistent_term:get({?MODULE, Option}, Default).

env([Option | Rest], Options, Default) ->
    case maps:get(Option, Options, undefined) of
        Value when Rest =:= [] -> Value;
        Value when is_map(Value) ->
            env(Rest, Value, Default);
        _Value -> Default
    end.

reload() ->
    {ok, File} = application:get_env(?MODULE, config),
    case filename:extension(File) of
        Ext when Ext =:= <<".yml">>; Ext =:= <<".yaml">>; Ext =:= ".yml"; Ext =:= ".yaml" ->
            load_yaml(File);
        Ext when Ext =:= <<".json">>; Ext =:= ".json" ->
            load_json(File)
    end.

load_yaml(File) ->
    [Config] = yamerl:decode_file(File, [{str_node_as_binary, true}, {map_node_format, map}]),
    store(Config).

load_json(File) ->
    {ok, Data} = file:read_file(File),
    store(jsx:decode(Data, [return_maps])).

store(Config) ->
    maps:fold(fun store/3, [], Config).

store(Key, Value, _Acc) ->
    persistent_term:put({?MODULE, Key}, Value).
