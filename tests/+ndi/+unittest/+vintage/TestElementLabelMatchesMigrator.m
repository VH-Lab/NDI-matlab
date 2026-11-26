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
%   SINCE [variable terms batch 1] (Decided by Jess Haley, 2026-11-19,
%   did-schema docs/plans/did_v2_go_forward_class_audit.md) the class
%   variable is the node EMPTY:0000401 "software class", which DID-matlab
%   writes through did2.convert.registeredTerm. NDI reads the node first and
%   the old phrase too, so the migrator may write either; the tests fail when
%   it writes neither, or writes the class variable at more than one site.
%
%   See also: ndi.vintage.elementLabel, ndi.vintage.elementSubjectDocs,
%             ndi.vintage.elementClassVariable.

    methods (Test)

        function testBothLabelsAppearInTheMigratorThatWritesThem(testCase)
            src = ndi.unittest.vintage.TestElementLabelMatchesMigrator.migratorSource(testCase);

            % DENOMINATOR: the variables this repository will search for.
            typeLabel = ndi.vintage.elementLabel('type');
            classLabel = ndi.vintage.elementLabel('class');
            classVar = ndi.vintage.elementClassVariable();
            testCase.log(sprintf( ...
                ['DENOMINATOR: 2 variable(s) (the type phrase "%s"; the class ' ...
                 'variable, node %s or the old phrase "%s"); migrator source is %d char(s)'], ...
                typeLabel, classVar.node, classLabel, numel(src)));

            testCase.verifySubstring(src, ['''' typeLabel ''''], sprintf( ...
                ['NDI searches for the label "%s" and DID-matlab''s ' ...
                 'element migrator does not write it. Nothing errors ' ...
                 'when these drift -- getprobes simply returns nothing ' ...
                 '-- so this test is the only thing that notices.'], ...
                typeLabel));

            % The class variable: Decided by Jess Haley, 2026-11-19
            % [variable terms batch 1] (did-schema
            % docs/plans/did_v2_go_forward_class_audit.md) moves it to the
            % node EMPTY:0000401 "software class". NDI reads both
            % (ndi.vintage.elementClassQuery), so the migrator may write
            % either the node lookup or the old phrase; it must write one.
            [nNode, nPhrase] = ndi.unittest.vintage.TestElementLabelMatchesMigrator.classSites(src);
            testCase.verifyGreaterThan(nNode + nPhrase, 0, sprintf( ...
                ['NDI reads the element class variable by node %s or by the ' ...
                 'phrase "%s", and DID-matlab''s element migrator writes ' ...
                 'neither (no did2.convert.registeredTerm with that node, and ' ...
                 'not the phrase). Nothing errors when these drift -- ' ...
                 'getprobes simply returns nothing -- so this test is the ' ...
                 'only thing that notices.'], classVar.node, classLabel));
        end

        function testTheLabelIsWrittenInExactlyOnePlace(testCase)
            % A second writer would mean a second spelling could appear
            % without this test failing: the first site would still match
            % while documents from the second carried something else. The
            % single-site property is what makes a substring check
            % sufficient, so it is asserted rather than assumed. The node
            % lookup and the old phrase are counted together: one site
            % writes the class variable, in one of its two spellings.
            src = ndi.unittest.vintage.TestElementLabelMatchesMigrator.migratorSource(testCase);
            [nNode, nPhrase] = ndi.unittest.vintage.TestElementLabelMatchesMigrator.classSites(src);
            classVar = ndi.vintage.elementClassVariable();
            testCase.verifyEqual(nNode + nPhrase, 1, sprintf( ...
                ['the element class variable is written at %d site(s) in the ' ...
                 'element migrator (%d by node %s, %d as "%s"); this test ' ...
                 'assumes exactly 1. More than one means a second spelling ' ...
                 'could be introduced at a site this check still passes over.'], ...
                nNode + nPhrase, nNode, classVar.node, nPhrase, ...
                ndi.vintage.elementLabel('class')));
        end

        function testTheSiteCounterSeesBothSpellings(testCase)
            % The counter itself, on fixed text, so a regression in it
            % cannot pass the two tests above by reading zero everywhere.
            nl = newline;
            [n, p] = ndi.unittest.vintage.TestElementLabelMatchesMigrator.classSites( ...
                'x = did2.convert.registeredTerm(''EMPTY:0000401'', ''software class'');');
            testCase.verifyEqual([n p], [1 0], 'the node lookup');
            [n, p] = ndi.unittest.vintage.TestElementLabelMatchesMigrator.classSites( ...
                'a = kindAssertion(preBody, id, ''ndi element class'', c);');
            testCase.verifyEqual([n p], [0 1], 'the old phrase');
            [n, p] = ndi.unittest.vintage.TestElementLabelMatchesMigrator.classSites( ...
                'a = jLabel(''element type'');');
            testCase.verifyEqual([n p], [0 0], 'neither');
            [n, p] = ndi.unittest.vintage.TestElementLabelMatchesMigrator.classSites( ...
                ['% did2.convert.registeredTerm(''EMPTY:0000401'', ''software class'')' nl ...
                 '% ''ndi element class''' nl 'y = 1;']);
            testCase.verifyEqual([n p], [0 0], 'a comment is not a site');
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
            src = ndi.unittest.vintage.TestElementLabelMatchesMigrator.codeOnly(fileread(p));
        end

        function [nNode, nPhrase] = classSites(src)
            % The sites in SRC (code only: codeOnly) that write the element
            % class variable: by node, a did2.convert.registeredTerm call
            % naming EMPTY:0000401 ([variable terms batch 1]), and as the
            % old phrase 'ndi element class' in single quotes.
            code = ndi.unittest.vintage.TestElementLabelMatchesMigrator.codeOnly(src);
            classVar = ndi.vintage.elementClassVariable();
            nNode = numel(regexp(code, ['registeredTerm\(\s*[''"]' ...
                regexptranslate('escape', classVar.node) '[''"]'], 'start'));
            nPhrase = numel(strfind(code, ['''' ndi.vintage.elementLabel('class') '''']));
        end

        function code = codeOnly(src)
            % Only code writes a label. A comment that quotes the phrase
            % (DID-matlab #442 quotes 'ndi element class' in the header of
            % element.m, citing [ndi element class not kept]) is not a
            % site, and counting it made the one-site check read two.
            % Whole-line comments and %{ ... %} blocks are dropped; a
            % trailing comment after code is kept, because finding where
            % it starts needs MATLAB's string rules and dropping too much
            % would hide a real site.
            lines = regexp(src, '\r?\n', 'split');
            keep = true(size(lines));
            inBlock = false;
            for i = 1:numel(lines)
                t = strtrim(lines{i});
                if inBlock
                    keep(i) = false;
                    if strcmp(t, '%}')
                        inBlock = false;
                    end
                elseif strcmp(t, '%{')
                    keep(i) = false;
                    inBlock = true;
                elseif startsWith(t, '%')
                    keep(i) = false;
                end
            end
            code = strjoin(lines(keep), newline);
        end

    end

end
