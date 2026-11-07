function [ok, clk, t0, t1] = anchorClockExtent(p)
%ANCHORCLOCKEXTENT A relative_time_reference's clock and its [t0 t1] on it.
%
%   [OK, CLK, T0, T1] = anchorClockExtent(PROPS) reads PROPS (a
%   relative_time_reference's document_properties): CLK the clock's handle
%   (ndi.v2.vocabHandle), T0 its start seconds, T1 its end seconds (or start
%   plus duration). OK is true when all three are read. Used by
%   private/archiveOf and ndi.vintage.ingestedArchives ('ClocksOnly').
ok = false; clk = ''; t0 = []; t1 = [];
if ~isfield(p, 'relative_time_reference') || ~isstruct(p.relative_time_reference) ...
        || ~isfield(p.relative_time_reference, 'value') || ~isstruct(p.relative_time_reference.value)
    return;
end
v = p.relative_time_reference.value;
if ~isfield(v, 'clock') || isempty(v.clock) || ~isfield(v, 'start')
    return;
end
clk = char(ndi.v2.vocabHandle('clock', v.clock));
t0 = secondsOf(v.start);
if isempty(clk) || isempty(t0); return; end
if isfield(v, 'end'); t1 = secondsOf(v.end); end
if isempty(t1) && isfield(v, 'duration')
    d = secondsOf(v.duration);
    if ~isempty(d); t1 = t0 + d; end
end
ok = ~isempty(t1);
end

function s = secondsOf(x)
s = [];
if isstruct(x) && ~isempty(x) && isfield(x, 'seconds') && ~isempty(x(1).seconds) ...
        && isnumeric(x(1).seconds)
    s = double(x(1).seconds);
end
end
