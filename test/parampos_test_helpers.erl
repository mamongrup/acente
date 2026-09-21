-module(parampos_test_helpers).
-export([statements/1]).
%% Test migration has ordinary SQL and $$ quoted PL/pgSQL bodies.
statements(Sql) ->
  [unicode:characters_to_binary(string:trim(S)) || S <-
    re:split(Sql, ";(?=(?:[^$]*\\$\\$[^$]*\\$\\$)*[^$]*$)", [{return,list}]),
    string:trim(S) =/= ""].
