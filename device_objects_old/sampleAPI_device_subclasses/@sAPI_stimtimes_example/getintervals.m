function [intervals] = getintervals(device)
%
%   INTERVALS = getintervals(stim)
%
%   Returns the epoch onset time and duration as a set of intervals
%   [ Onset_time_1 Duration_1 ; 
%     Onset_time_2 Duration_2 ; 
%     ...
%     Onset_time_n Duration_n ];
% 

intervals = [];
for (i <= size(device.stim_times,1) )
intervals(:,1) = device.stim_times(,2);
intervals(:,2) = device.stim_times(,3) - device.stim_times(,2);
intervals(:,3) = device.voltageForTime; 

return;  

