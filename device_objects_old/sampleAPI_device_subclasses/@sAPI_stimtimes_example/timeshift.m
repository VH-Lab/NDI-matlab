function [tshift, alpha, info] = timeshift(D1, D2, interval1, interval2)
% TIMESHIFT - calculate the timeshift between two epochs recorded on different devices
%
%  [TSHIFT, ALPHA, INFO] = TIMESHIFT(D1, D2, INTERVAL1, INTERVAL2)
%
%  Calculates the time shift (in the shift TSHIFT and scale ALPHA) between
%  recording epochs from a device D1 and device D2. It will examine the
%  INTERVAL1-th epoch from device D1, and the INTERVAL2-th epoch from
%  device D2.
%
%  This function only examines local shifts, it does not search for all
%  possible shifts.
%
%  If there is no match, TSHIFT and ALPHA will be empty.
%
%  The conversion formula is time_D2 = alpha * time_D1 + tshift
%
%  INFO describes the quality of the match, and can be 
%      1 - Exact
%      2 - Approximate (within a second)
%      3 - No information
%


tshift = [];
alpha = [];
info = 3;

if isa(D2,'sAPI_stimtimes_example') | isa(D2,'sAPI_ephys_example'),
	if (interval1 ~=1) | (interval2 ~=1), return; end;
	tshift = 0; 
	alpha = 1;
	info = 1;
end;

return; 

if strcmp(D1,'D1') | strcmp(D2,'D1'),
    intervals = sampleAPI_getintervals('D1');
    alpha = 1;
    tshift = intervals(interval2,1) - intervals(interval1,1);
    info = 1;
    return;
end;


if strcmp(D1,'D1') & strcmp(D2,'D2'), 
    % imagine simple scenario where tshift = 2, alpha = 1
    if interval1==interval2,
        alpha = 1; tshift = 2; info = 1;
    end;
end;

if strcmp(D1,'D2') & strcmp(D2,'D1'), 
    % imagine simple scenario where tshift = -2, alpha = 1
    if interval1==interval2,
        alpha = 1; tshift = -2; info = 1;
    end;
end;

if strcmp(D1,'D2') & strcmp(D2,'D3'), 
    % imagine simple scenario where tshift = 5, alpha = 1
    if interval1==interval2,
        alpha = 1; tshift = 5; info = 1;
    end;
end;

if strcmp(D1,'D3') & strcmp(D2,'D2'), 
    % imagine simple scenario where tshift = -5, alpha = 1
    if interval1==interval2,
        alpha = 1; tshift = -5; info = 1;
    end;
end;

