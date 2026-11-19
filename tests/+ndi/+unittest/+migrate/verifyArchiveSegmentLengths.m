function R = verifyArchiveSegmentLengths(testCase, result, v1Bodies, label, options)
%VERIFYARCHIVESEGMENTLENGTHS The ingested archives' segment lengths after NDI's second pass, against v1.
%
%   R = ndi.unittest.migrate.verifyArchiveSegmentLengths(TESTCASE, RESULT, ...
%       V1BODIES, LABEL) reads RESULT.secondPass.archiveSegmentLengths (the
%   report ndi.migrate.local writes with
%   ndi.migrate.internal.archiveSegmentLengths), prints it with its
%   denominator first, and checks it.
%
%   Decided by Jess Haley, 2026-11-12 [archive segment lengths measured after
%   the second pass] (did-schema did_v2_go_forward_class_audit.md): the
%   second-pass end-to-end compares each v1 archive's
%   sample_analog_segment and sample_digital_segment (deferred to the second
%   pass by DID-matlab's whole-batch round trip) with the v1 values.
%
%   CHECKED, always:
%     the report is there (the step ran and did not throw)
%     the denominator: archives_inspected is the number of v1
%       daqreader_mfdaq_epochdata_ingested documents in V1BODIES, counted
%       here by decoding each (not by the step's own filter)
%     the partition: measured + not measured (by reason) = inspected, and
%       per field compared = equal + differ, v1_stated = compared +
%       no_v2_home + no_digital_default
%     no measured value differs from its v1 value
%   CHECKED with 'RequireMeasured', true (a fixture whose bytes are here):
%     every archive is measured, and at least one value of each field the
%     bodies hold is compared
%   REPORTED, never asserted: the not-measured archives by reason (a corpus
%   zip carries no binary files, NDI-matlab #785, so a corpus run reads "not
%   measured"); `no_digital_default`, the sample_digital_segment of an
%   archive with no digital series, at the v1 ingest's fixed default 1e7
%   (notation: Decided by Jess Haley, 2026-11-19 [archive with no digital
%   channel]); and `no_v2_home`, any other stated v1 value no converted body
%   holds; what that means is the team's question.

arguments
    testCase
    result struct
    v1Bodies cell
    label (1,:) char
    options.RequireMeasured (1,1) logical = false
end

R = [];
testCase.assertTrue(isfield(result, 'secondPass') && ...
    isfield(result.secondPass, 'archiveSegmentLengths'), ...
    sprintf('%s: the migration result has no secondPass.archiveSegmentLengths', label));
R = result.secondPass.archiveSegmentLengths;
testCase.assertNotEmpty(R, sprintf(['%s: the segment-length comparison did not run ' ...
    '(or threw; see result.secondPassErrors)'], label));

expected = countV1Archives(v1Bodies);
fprintf(['\n  INGESTED ARCHIVE SEGMENT LENGTHS AFTER THE SECOND PASS (%s)\n' ...
    '    DENOMINATOR: %d v1 archive(s) inspected (%d counted in the v1 bodies); ' ...
    '%d v2 body(ies) read\n' ...
    '    %s: %d measured, %d not measured (bytes absent %d, not converted %d, ' ...
    'no v2 body %d)\n'], label, R.archives_inspected, expected, R.bodies_inspected, ...
    upper(R.state), R.archives_measured, R.archives_not_measured, ...
    R.not_measured_bytes_absent, R.not_measured_not_converted, R.not_measured_no_v2_body);
for w = {'analog', 'digital'}
    c = R.(w{1});
    fprintf(['    %s: %d stated in v1 (measured archives); %d compared: %d equal, %d ' ...
        'differ; %d the no-digital default (notation); %d with no v2 home; %d rebuilt ' ...
        'with no v1 value\n'], c.field, c.v1_stated, c.compared, c.equal, c.differ, ...
        c.no_digital_default, c.no_v2_home, c.v2_without_v1);
end
for i = 1:numel(R.differences)
    d = R.differences(i);
    fprintf('    DIFFERS: %s %s: %s\n', d.archive_id, d.field, d.why);
end

testCase.verifyEqual(R.archives_inspected, expected, sprintf( ...
    '%s: the step inspected %d v1 archive(s); the v1 bodies hold %d', label, ...
    R.archives_inspected, expected));
testCase.verifyEqual(R.archives_measured + R.not_measured_bytes_absent + ...
    R.not_measured_not_converted + R.not_measured_no_v2_body, R.archives_inspected, ...
    sprintf('%s: measured + not measured is not the archives inspected', label));
testCase.verifyEqual(R.archives_measured + R.archives_not_measured, R.archives_inspected, ...
    sprintf('%s: archives_not_measured does not complete the denominator', label));
for w = {'analog', 'digital'}
    c = R.(w{1});
    testCase.verifyEqual(c.equal + c.differ, c.compared, ...
        sprintf('%s: %s compared is not equal + differ', label, c.field));
    testCase.verifyEqual(c.compared + c.no_v2_home + c.no_digital_default, c.v1_stated, ...
        sprintf('%s: %s stated is not compared + no v2 home + the no-digital default', ...
        label, c.field));
    testCase.verifyEqual(c.differ, 0, sprintf( ...
        '%s: %d %s value(s) rebuilt from the v2 bodies differ from v1 (first: %s)', ...
        label, c.differ, c.field, firstWhy(R, c.field)));
end
if options.RequireMeasured
    testCase.verifyGreaterThan(R.archives_inspected, 0, ...
        sprintf('%s: no v1 archive to compare', label));
    testCase.verifyEqual(R.archives_measured, R.archives_inspected, sprintf( ...
        '%s: %d of %d archive(s) not measured (bytes absent %d, not converted %d, no v2 body %d)', ...
        label, R.archives_not_measured, R.archives_inspected, R.not_measured_bytes_absent, ...
        R.not_measured_not_converted, R.not_measured_no_v2_body));
    testCase.verifyGreaterThan(R.analog.compared + R.digital.compared, 0, ...
        sprintf('%s: no segment length compared', label));
end
end

function n = countV1Archives(v1Bodies)
n = 0;
for k = 1:numel(v1Bodies)
    b = v1Bodies{k};
    if ischar(b) || isstring(b)
        if ~contains(b, 'daqreader_mfdaq_epochdata_ingested'); continue; end
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    if isstruct(b) && isscalar(b) && isfield(b, 'document_class') ...
            && isfield(b.document_class, 'class_name') ...
            && strcmp(char(b.document_class.class_name), 'daqreader_mfdaq_epochdata_ingested')
        n = n + 1;
    end
end
end

function s = firstWhy(R, field)
s = 'none listed';
for i = 1:numel(R.differences)
    if strcmp(R.differences(i).field, field)
        s = R.differences(i).why;
        return;
    end
end
end
