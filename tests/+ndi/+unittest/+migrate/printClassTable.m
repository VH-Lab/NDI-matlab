function printClassTable(byClass, label)
%PRINTCLASSTABLE Render a v1_to_v2 by-class counter, including when it is empty.
%   printClassTable(BYCLASS, LABEL) prints one line per class in BYCLASS --
%   a `summary.*_by_class` struct from did2.convert.v1_to_v2 -- sorted by
%   count, largest first.
%
%   IT PRINTS SOMETHING WHEN THE TABLE IS EMPTY, and that is the whole reason
%   it exists rather than being three lines at each call site. v1_to_v2's own
%   printUnconverted returns EARLY on a zero count (v1_to_v2.m:1122), which is
%   right for a summary and wrong for a test log: "no classes deferred" and
%   "this counter was never populated" then look identical on screen, which is
%   the silentLoss defect in its render layer. Here the empty case prints
%   `(none)` -- a measurement, not a silence.

arguments
    byClass (1,1) struct
    label   (1,:) char
end

names = fieldnames(byClass);
if isempty(names)
    fprintf('%s by class: (none)\n', label);
    return;
end

counts = zeros(numel(names), 1);
for k = 1:numel(names)
    counts(k) = byClass.(names{k});
end
[counts, order] = sort(counts, 'descend');
names = names(order);

fprintf('%s by class: %d class(es)\n', label, numel(names));
for k = 1:numel(names)
    fprintf('      %6d  %s\n', counts(k), names{k});
end
end
