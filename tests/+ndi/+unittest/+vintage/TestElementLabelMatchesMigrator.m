classdef TestElementLabelMatchesMigrator < matlab.unittest.TestCase
%TESTELEMENTLABELMATCHESMIGRATOR One phrase, two repositories, nothing else checking.
%
%   V_eta turns a v1 `element` into a `subject` plus an inbound
%   `term_assertion` whose label carries the MATLAB class name. That label
%   is a typed phrase. DID-matlab writes it in one file; NDI reads it in
%   one file; the two are in different repositories and no compiler, no
%   schema and no validator compares them.
%
%   IF THEY EVER DIFFER, NOTHING ERRORS. NDI asks for a label nothing
%   carries, gets an empty result, and `getprobes` returns {} exactly as
%   it would for a dataset with no probes. That is the silent-empty
%   failure the whole ndi.vintage layer exists to remove -- so leaving its
%   own foundation unguarded would be the failure reintroduced one level
%   up.
%
%   This test opens the migrator and asserts the phrases still match. It
%   is deliberately a STRING COMPARISON AGAINST SOURCE rather than a
%   shared constant: a shared constant is exactly what does not exist
%   across a repository boundary, and pretending otherwise is what the
%   test is here to prevent.
%
%   WHY NOT JUST BIND THE TERM PROPERLY: the tidy form is a bound
%   ontology term rather than a phrase. `subject_statement.variable` is
%   already bound in FORM but not in VOCABULARY -- did-schema's open T8
%   item -- and the vocabulary lives in a repository outside this work, so
%   it is blocked regardless. This buys the safety in the meantime; see
%   ndi.vintage.elementLabel.
%
%   See also: ndi.vintage.elementLabel, ndi.vintage.elementSubjectDocs.

    methods (Test)

        function testBothLabelsAppearInTheMigratorThatWritesThem(testCase)
            src = ndi.unittest.vintage.TestElementLabelMatchesMigrator.migratorSource(testCase);

            % DENOMINATOR: the labels this repository will search for.
            labels = {ndi.vintage.elementLabel('class'), ...
                      ndi.vintage.elementLabel('type')};
            testCase.log(sprintf( ...
                'DENOMINATOR: %d label(s) declared by ndi.vintage.elementLabel; migrator source is %d char(s)', ...
                numel(labels), numel(src)));

            for i = 1:numel(labels)
                testCase.verifySubstring(src, ['''' labels{i} ''''], sprintf( ...
                    ['NDI searches for the label "%s" and DID-matlab''s ' ...
                     'element migrator does not write it. Nothing errors ' ...
                     'when these drift -- getprobes simply returns nothing ' ...
                     '-- so this test is the only thing that notices.'], ...
                    labels{i}));
            end
        end

        function testTheLabelIsWrittenInExactlyOnePlace(testCase)
            % A second writer would mean a second spelling could appear
            % without this test failing: the first site would still match
            % while documents from the second carried something else. The
            % single-site property is what makes a substring check
            % sufficient, so it is asserted rather than assumed.
            src = ndi.unittest.vintage.TestElementLabelMatchesMigrator.migratorSource(testCase);
            label = ndi.vintage.elementLabel('class');
            n = numel(strfind(src, ['''' label '''']));
            testCase.verifyEqual(n, 1, sprintf( ...
                ['"%s" is written at %d site(s) in the element migrator; ' ...
                 'this test assumes exactly 1. More than one means a ' ...
                 'second spelling could be introduced at a site this ' ...
                 'check still passes over.'], label, n));
        end

    end

    methods (Static, Access = private)

        function src = migratorSource(testCase)
            % The migrator is a package function in the DID-matlab
            % dependency, so it is located through `which` rather than a
            % relative path -- the two repositories are checked out
            % side-by-side in one job and installed as a dependency in
            % another, and only the MATLAB path knows which.
            p = which('did2.convert.migrators_j.element');
            if isempty(p) || ~isfile(p)
                % ASSUMPTION FAILURE, NOT A TEST FAILURE. "DID-matlab is
                % not on the path" and "the labels disagree" are different
                % findings and must not print the same result.
                assumeFail(testCase, ...
                    ['DID-matlab''s element migrator is not on the path, ' ...
                     'so the two labels cannot be compared here.']);
            end
            src = fileread(p);
        end

    end

end
