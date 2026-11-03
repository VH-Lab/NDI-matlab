function verifyObjectEquivalence(testCase, R)
%VERIFYOBJECTEQUIVALENCE Verify a corpusObjectEquivalence report found no difference.
%
%   ndi.unittest.migrate.verifyObjectEquivalence(TESTCASE, R) takes the
%   report of ndi.unittest.migrate.corpusObjectEquivalence and verifies:
%     DENOMINATORS FIRST: every v1 document went into the v1 database, at
%       least one session was compared, every session found on both sides
%       opened on both, and subjects, elements, probes and acquisition
%       systems were compared (a comparison of nothing finds nothing);
%     no session on one side only;
%     in every category: nothing differs, nothing is on one side only;
%     the write round trip compared its two documents.
%   Apparatus and equipment entities are counted in the report, not
%   verified: v1 has no subject object to compare them with.

arguments
    testCase matlab.unittest.TestCase
    R (1,1) struct
end

L = R.label;
testCase.verifyEqual(R.v1db.added, R.v1db.read, sprintf( ...
    ['%s: %d of %d v1 document(s) went into the v1 database; the v1 side ' ...
     'is missing the rest (%s)'], L, R.v1db.added, R.v1db.read, ...
    strjoin(R.v1db.refusals, ' | ')));
testCase.assertGreaterThan(R.sessions.compared, 0, sprintf( ...
    '%s: no session was compared, so nothing below is a measurement', L));
testCase.verifyEmpty(R.sessions.errors, sprintf('%s: a session did not open: %s', ...
    L, strjoin(R.sessions.errors, ' | ')));
testCase.verifyEmpty(R.sessions.only_v1, sprintf( ...
    '%s: session(s) with no migrated record: %s', L, strjoin(R.sessions.only_v1, ', ')));
testCase.verifyEmpty(R.sessions.only_v2, sprintf( ...
    '%s: migrated session record(s) with no v1 session: %s', L, ...
    strjoin(R.sessions.only_v2, ', ')));

for c = {'subject', 'element', 'probe', 'daq_system'}
    testCase.verifyGreaterThan(R.cats.(c{1}).compared, 0, sprintf( ...
        '%s: no %s was compared', L, c{1}));
end
testCase.verifyEqual(R.cats.write_round_trip.compared, 2, sprintf( ...
    '%s: the write round trip did not compare its two documents', L));

names = fieldnames(R.cats);
for k = 1:numel(names)
    C = R.cats.(names{k});
    detail = '';
    for m = 1:numel(C.kinds)
        detail = sprintf('%s\n  %s: %d', detail, C.kinds{m}, C.kindCounts(m));
        if ~isempty(C.examples{m})
            detail = sprintf('%s (e.g. %s)', detail, C.examples{m}{1});
        end
    end
    testCase.verifyEqual([C.differ C.only_v1 C.only_v2], [0 0 0], sprintf( ...
        '%s / %s: of %d compared, %d differ; %d only in v1, %d only after migration%s', ...
        L, names{k}, C.compared, C.differ, C.only_v1, C.only_v2, detail));
end
end
