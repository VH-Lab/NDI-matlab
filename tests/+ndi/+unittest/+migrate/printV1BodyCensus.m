function printV1BodyCensus(census, corpusName)
%PRINTV1BODYCENSUS Print a finalV1BodyCensus result, DENOMINATOR FIRST.
%   printV1BodyCensus(CENSUS, CORPUSNAME) prints the three tables separately:
%     (a) unconverted v1 bodies          -- FLAGGED, a Bar-2 gap
%     (b) v1-spelled real V2 classes     -- counted, not flagged
%     (c) known deferrals                -- FLAGGED, still v1 bodies, declared
%   `same-id` is how many rows have a SOURCE document with the same base.id
%   and the same class: for an unconverted body that is every one of them.

d = census.denominator;
nA = sumCounts(census.unconverted);
nB = sumCounts(census.v2_classes);
nC = sumCounts(census.deferred);
fprintf(['\n  BAR-2 FINAL-OUTPUT V1 BODY CENSUS (%s)\n' ...
         '    DENOMINATOR: %d source document(s) read, %d classified; ' ...
         '%d destination document(s) read, %d under a v1 class spelling; ' ...
         'v1 vocabulary %d name(s)\n' ...
         '    signal: the destination document''s own superclass chain ' ...
         '(rebuilt from the pinned schema) -- all-v1 = v1 body\n' ...
         '    (a) unconverted v1 bodies (FLAGGED):          %d\n' ...
         '    (b) v1 spelling, real V2 class (not flagged): %d\n' ...
         '    (c) known deferrals (FLAGGED, declared):      %d\n' ...
         '    check: a + b + c = %d of %d v1-spelled\n'], ...
    corpusName, d.source_read, d.source_classified, d.dest_read, ...
    d.dest_v1_spelled, d.v1_vocabulary_size, nA, nB, nC, ...
    nA + nB + nC, d.dest_v1_spelled);

fprintf('    (a) UNCONVERTED v1 BODIES -- a Bar-2 gap unless declared\n');
if isempty(census.unconverted)
    fprintf('      (none)\n');
end
for k = 1:numel(census.unconverted)
    r = census.unconverted(k);
    fprintf('      %6d  %-42s same-id %6d  chain: %s\n', r.count, ...
        r.class_name, r.same_id_source, r.chain);
end

fprintf('    (b) v1 SPELLING, REAL V2 CLASS ON THIS SCHEMA -- counted, not flagged\n');
if isempty(census.v2_classes)
    fprintf('      (none)\n');
end
for k = 1:numel(census.v2_classes)
    r = census.v2_classes(k);
    fprintf('      %6d  %-42s same-id %6d  via V_eta ancestor `%s`\n', ...
        r.count, r.class_name, r.same_id_source, r.veta_ancestor);
end

fprintf('    (c) KNOWN DEFERRALS -- still v1 bodies, declared\n');
if isempty(census.deferred)
    fprintf('      (none)\n');
end
for k = 1:numel(census.deferred)
    r = census.deferred(k);
    fprintf('      %6d  %-42s same-id %6d  %s\n', r.count, ...
        r.class_name, r.same_id_source, r.label);
end
end

function n = sumCounts(rows)
if isempty(rows)
    n = 0;
else
    n = sum([rows.count]);
end
end
