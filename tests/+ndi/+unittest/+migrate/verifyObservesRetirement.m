function r = verifyObservesRetirement(testCase, result, label)
%VERIFYOBSERVESRETIREMENT The second pass's `observes` retirement, counted, on a migrated corpus.
%
%   R = ndi.unittest.migrate.verifyObservesRetirement(TESTCASE, RESULT, LABEL)
%   reads RESULT.secondPass.observesRetirement (ndi.migrate.local) and prints
%   it, the denominators first: Decided by Jess Haley, 2026-11-17
%   [observes retires in the second pass] (did-schema
%   did_v2_go_forward_class_audit.md), NDI's second pass retires a
%   stimulator's `observes` relation where a converted stimulus presentation
%   names the same device as instrument and the same animal as entity. It
%   verifies that the step ran (no step error, a report), that every
%   relation read is retired or kept under one reason, and that every
%   relation it retired was removed from the batch. How many retire is the
%   calling test's to state. Whether the retired stimulators still read
%   their subject is ndi.unittest.migrate.corpusObjectEquivalence's (elements
%   and probes: subject, direct).

r = result.secondPass.observesRetirement;
if isfield(result, 'secondPassErrors') && isstruct(result.secondPassErrors) ...
        && isfield(result.secondPassErrors, 'steps') && ~isempty(result.secondPassErrors.steps)
    steps = {result.secondPassErrors.steps.step};
    testCase.verifyFalse(any(strcmp(steps, 'observesRetirementFailed')), ...
        'the `observes` retirement step threw');
end
testCase.assertTrue(isstruct(r) && isfield(r, 'observes_seen'), ...
    'the second pass carries no observesRetirement report (the step did not run)');
fprintf(['\n  OBSERVES RETIREMENT (%s): %d document(s) inspected, %d `observes` relation(s), ' ...
    '%d presentation manipulation(s) naming %d instrument(s)\n' ...
    '    retired %d (removed %d); kept %d: no presentation %d, other entity %d, ' ...
    'several entities %d, several parents %d, incomplete %d\n'], label, ...
    r.documents_inspected, r.observes_seen, r.presentation_manipulations, ...
    r.presentation_instruments, r.observes_retired, r.removed, r.observes_kept, ...
    r.kept_no_presentation, r.kept_other_entity, r.kept_several_entities, ...
    r.kept_several_observes, r.kept_incomplete);
testCase.verifyGreaterThan(r.documents_inspected, 0, 'the step read no document (nothing measured)');
testCase.verifyEqual(r.observes_retired + r.observes_kept, r.observes_seen, ...
    'a relation read was neither retired nor kept');
testCase.verifyEqual(r.removed, r.observes_retired, ...
    'the step removed a different number of relations than it retired');
end
