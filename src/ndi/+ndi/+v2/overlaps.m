function [tf, decided] = overlaps(times, window, tolerant)
%OVERLAPS Does a statement's time overlap a window (a stay)?
%
%   [TF, DECIDED] = ndi.v2.overlaps(TIMES, WINDOW, TOLERANT): TIMES is a cell
%   of the statement's resolved time references (structs from ndi.v2.timeOf);
%   WINDOW has start, end (UTC datetimes), tol and end_tol ([minus plus]
%   seconds). TF is true when any of the times overlaps the window, ends
%   included. DECIDED is false when none of the times could be compared: no
%   time, or one known only as a bound on its anchor ('before the seeding').
%   TOLERANT (default false) widens both by their tolerances.
%
%   See also ndi.v2.stays, ndi.v2.timeFilter.

if nargin < 3, tolerant = false; end
tf = false; decided = false;
if isnat(window.start) || isnat(window.end), return; end
wS = window.start; wE = window.end;
if tolerant
    wS = wS - seconds(window.tol(1));
    wE = wE + seconds(window.end_tol(2));
end
for k = 1:numel(times)
    t = times{k};
    if isempty(t) || isnat(t.start) || strcmp(t.resolved_by, 'relation'), continue; end
    s = t.start; e = t.end;
    if isnat(e), e = s; end
    if tolerant
        tolS = zeroNaN(t.tolerance); tolE = zeroNaN(t.end_tolerance);
        if all(tolE == 0), tolE = tolS; end
        s = s - seconds(tolS(1)); e = e + seconds(tolE(2));
    end
    decided = true;
    if s <= wE && e >= wS
        tf = true;
        return;
    end
end
end

function t = zeroNaN(t)
% [minus plus] seconds, 0 where unknown
if isempty(t), t = [0 0]; end
if isscalar(t), t = [t t]; end
t(isnan(t)) = 0;
end
