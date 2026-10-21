classdef TestSyncruleParameters < matlab.unittest.TestCase
%TESTSYNCRULEPARAMETERS ndi.vintage.syncruleParameters on the did-schema #88
%   clock_alignment_configuration a migrated file-based syncrule becomes.
%
%   e2e run 39675528253 (PRED and 20211116): opening a migrated session
%   failed in ndi.time.syncgraph with NDI:vintage:syncruleMissingField
%   ("configuration carries no `minimum_matching_file_paths`"), although the
%   count was there. DID-matlab's #88 syncrule migrator writes it as a method
%   parameter labelled 'minimum matching file paths' (+migrators_j/syncrule.m,
%   jLabel), with spaces; the reader compared the label to
%   'minimum_matching_file_paths' / 'number_fullpath_matches' exactly.

    methods (Test)

        function testTheSpacedLabelIsRead(testCase)
            % the shape read back from PRED's migrated database
            doc = configDoc('minimum matching file paths', 2);
            params = ndi.vintage.syncruleParameters(doc, [], ...
                'ndi.time.syncrule.filematch');
            testCase.verifyEqual(params.number_fullpath_matches, 2);
        end

        function testTheFieldNameAndTheV1NameStillRead(testCase)
            for name = {'minimum_matching_file_paths', 'number_fullpath_matches'}
                doc = configDoc(name{1}, 3);
                params = ndi.vintage.syncruleParameters(doc, [], ...
                    'ndi.time.syncrule.filematch');
                testCase.verifyEqual(params.number_fullpath_matches, 3, name{1});
            end
        end

        function testAnUnrelatedLabelIsStillAnError(testCase)
            % the reader still refuses to invent the count
            doc = configDoc('minimum embedded file overlap', 2);
            testCase.verifyError(@() ndi.vintage.syncruleParameters(doc, [], ...
                'ndi.time.syncrule.filematch'), 'NDI:vintage:syncruleMissingField');
        end

    end
end

function doc = configDoc(label, count)
p = struct();
p.document_class = struct('class_name', 'clock_alignment_configuration', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
p.depends_on = struct('name', 'session_id', 'value', 'sess_1');
p.base = struct('id', 'cfg_1', 'creation_timestamp', '2026-01-01T00:00:00.000Z');
p.clock_alignment_configuration = struct('method', struct('parameters', ...
    struct('variable', struct('name', label), 'count', count)));
doc = ndi.document(p);
end
