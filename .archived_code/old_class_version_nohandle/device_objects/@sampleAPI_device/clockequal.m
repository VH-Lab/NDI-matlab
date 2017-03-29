function [ compare ] = clockequal( AvailableClock1, AvailableClock2,clocktype)
%CLOCKEQUAL Summary of this function goes here
% check if can find the wanted clock type in the two device.
%   Detailed explanation goes here


boolean compare = true;

if ~isnan (AvailableClock1.clocktype) && ~isnan (AvailableClock2.clocktype) 
    compare = true;
else 
    compare = false;
    

    
end

