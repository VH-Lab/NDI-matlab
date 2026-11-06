function verifyReadPhases(testCase, T, options)
%VERIFYREADPHASES v2 reads no slower than v1, phase by phase, within a noise margin.
%
%   ndi.unittest.migrate.verifyReadPhases(TESTCASE, T) checks the timings
%   ndi.unittest.migrate.readPhaseTimings returned (T). For every phase,
%   summed over the corpus's sessions:
%
%       v2 seconds <= v1 seconds * (1 + RelativeMargin) + AbsoluteMargin
%
%   Jess Haley, 2026-11-06: "Speed can't be slower than v1. We need to
%   match or beat." The margin is noise only (Proposed (not decided)):
%   RelativeMargin 0.10 and AbsoluteMargin 1.0 s. A phase is measured on one
%   shared runner, v1 then v2, so the same phase can move a few percent
%   between the two reads for reasons that are not the code; one second
%   covers the phases that take well under a second on both sides.
%
%   The denominator is asserted first: at least one session read, and no
%   phase that raised (a phase that raised has no time to compare).
%
%   'Enforce', false prints the verdict without failing (report-only).

arguments
    testCase
    T struct
    options.RelativeMargin (1,1) double = 0.10
    options.AbsoluteMargin (1,1) double = 1.0
    options.Enforce (1,1) logical = false
end

nErr = 0;
for i = 1:numel(T.sessions)
    nErr = nErr + numel(T.sessions(i).errors);
end
fprintf(['\n  READ-SPEED CHECK (%s): %d session(s), %d phase error(s); margin: ' ...
    'v2 <= v1 x %.2f + %.1f s per phase\n'], T.label, numel(T.sessions), nErr, ...
    1 + options.RelativeMargin, options.AbsoluteMargin);
slow = {};
for p = 1:numel(T.phases)
    ph = T.phases{p};
    a = T.v1.(ph);
    b = T.v2.(ph);
    limit = a * (1 + options.RelativeMargin) + options.AbsoluteMargin;
    ok = b <= limit;
    verdict = 'ok';
    if ~ok
        verdict = 'SLOWER THAN v1';
        slow{end+1} = sprintf('%s: v2 %.1f s against v1 %.1f s (limit %.1f s)', ph, b, a, limit); %#ok<AGROW>
    end
    fprintf('    %-16s v1 %9.1f s   v2 %9.1f s   limit %9.1f s   %s\n', ph, a, b, limit, verdict);
end
if ~options.Enforce
    if ~isempty(slow)
        fprintf('    REPORT-ONLY: %d phase(s) slower than v1 (not enforced here)\n', numel(slow));
    end
    return;
end
verifyGreaterThan(testCase, numel(T.sessions), 0, 'the read-speed check read no session');
verifyEqual(testCase, nErr, 0, 'a read phase raised, so its time cannot be compared');
verifyEmpty(testCase, slow, sprintf('v2 reads slower than v1 in %s:\n  %s', T.label, ...
    strjoin(slow, sprintf('\n  '))));
end
