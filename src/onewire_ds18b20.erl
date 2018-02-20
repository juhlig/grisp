-module(onewire_ds18b20).
% Device: DS18B20 - Programmable Resolution 1-Wire Digital Thermometer
% https://datasheets.maximintegrated.com/en/ds/DS18B20.pdf

% API
-export([temp/1]).
-export([read_scratchpad/1]).
-export([convert/1]).

-define(READ_SCRATCHPAD, 16#BE).
-define(CONVERT_T,       16#44).

%--- API -----------------------------------------------------------------------

temp(ID) ->
    grisp_onewire:transaction(fun() ->
        select_device(ID),
        {<<LSB>>, <<MSB>>, Config} = read_scratchpad(),
        Bits = bits(Config),
        <<_:4, Temp:Bits/signed-big, _/binary>> = <<MSB, LSB>>,
        Temp / 16.0
    end).

read_scratchpad(ID) ->
    grisp_onewire:transaction(fun() ->
        select_device(ID),
        read_scratchpad()
    end).

convert(ID) ->
    grisp_onewire:transaction(fun() ->
        select_device(ID),
        grisp_onewire:write_byte(?CONVERT_T),
        confirm(grisp_onewire:read_byte())
    end).

%--- Internal ------------------------------------------------------------------

select_device(ID) ->
    presence_detected = grisp_onewire:bus_reset(),
    grisp_onewire:write_byte(16#55),
    [grisp_onewire:write_byte(B) || B <- ID],
    ok.

read_scratchpad() ->
    grisp_onewire:write_byte(?READ_SCRATCHPAD),
    [LSB, MSB, _TH, _TL, Config, _, _, _, _CRC]
        = [grisp_onewire:read_byte() || _ <- lists:seq(0, 8)],
    {LSB, MSB, Config}.

bits(<<_:1, 0:1, 0:1, _:5>>) -> 9;
bits(<<_:1, 0:1, 1:1, _:5>>) -> 10;
bits(<<_:1, 1:1, 0:1, _:5>>) -> 11;
bits(<<_:1, 1:1, 1:1, _:5>>) -> 12.

confirm(<<16#00>>) ->
    timer:sleep(10),
    confirm(grisp_onewire:read_byte());
confirm(<<16#FF>>) ->
    ok.
