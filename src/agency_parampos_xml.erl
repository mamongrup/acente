-module(agency_parampos_xml).
-export([value/2]).
-include_lib("xmerl/include/xmerl.hrl").

%% SOAP may use namespace prefixes, CDATA or numeric XML entities.
%% Reject declarations before parsing to prevent entity expansion/fetching.
value(Xml, Name) ->
  case re:run(Xml, <<"<!\\s*(DOCTYPE|ENTITY)">>, [caseless]) of
    nomatch ->
      try
        {Root, _} = xmerl_scan:string(unicode:characters_to_list(Xml), [{quiet,true}]),
        Path = "//*[local-name()='" ++ binary_to_list(Name) ++ "']/text()",
        Text = [T#xmlText.value || T <- xmerl_xpath:string(Path, Root)],
        unicode:characters_to_binary(lists:flatten(Text))
      catch _:_ -> <<>> end;
    _ -> <<>>
  end.
