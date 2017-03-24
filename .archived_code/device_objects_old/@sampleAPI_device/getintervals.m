function [intervals] = getintervals(device,onset,offset)
%
%   INTERVALS = getintervals(device)
%
%   Returns the epoch onset time and duration as a set of intervals
%   [ Onset_time_1 Duration_1 ; 
%     Onset_time_2 Duration_2 ; 
%     ...
%     Onset_time_n Duration_n ];
% 

intervals = [ ];  % just an abstract class, no intervals

return;  

if strcmp(device,'D1'),
    intervals = [{ 5 100 } ; 110 57 ; 200 58; 300 400];
elseif strcmp(device,'D2'),
    intervals = [ NaN 50 ; NaN 30 ; NaN 60 ; NaN 150];
elseif strcmp(device,'D3'),
    intervals = [ NaN 40 ; NaN 60; NaN 150; NaN 500];    
end;
