classdef TestElementLocalIdentifier < matlab.unittest.TestCase
%TESTELEMENTLOCALIDENTIFIER A migrated element's local_identifier is '<name> | <reference>', both ways.
%
%   Decided by Jess Haley, 2026-10-26 [element local identifier is name and
%   reference] (did-schema V_eta_go_forward_class_audit.md): the
%   local_identifier is NDI's display form (ndi.element/elementstring,
%   [name ' | ' int2str(reference)]), read back by splitting at the LAST
%   ' | ' (the reference is an integer). It replaces '%s (ref %s)', which
%   is still read. ndi.vintage.elementLocalIdentifier writes it,
%   ndi.vintage.elementNameReference reads it, ndi.vintage.elementFields
%   rebuilds the element from it.

    properties (TestParameter)
        % names a split must survive: plain, holding ' | ', holding a
        % trailing ' | <integer>', holding ' (ref ', both, spaces
        pair = struct( ...
            'plain',          {{'leftcortex', 2}}, ...
            'pipe',           {{'a | b', 3}}, ...
            'pipe_integer',   {{'a | 4', 3}}, ...
            'ref_text',       {{'x (ref 7)', 1}}, ...
            'ref_at_end',     {{'probe (ref 9)', 12}}, ...
            'both',           {{'p | q (ref 2) | 5', 0}}, ...
            'negative',       {{'ctx', -1}}, ...
            'edge_spaces',    {{' cortex  ', 2}})
    end

    methods (Test)

        function testRoundTrip(testCase, pair)
            name = pair{1};
            ref = pair{2};
            [lid, ok] = ndi.vintage.elementLocalIdentifier(name, ref);
            testCase.assertTrue(ok, 'an integer reference is always reversible');
            testCase.verifyEqual(lid, [name ' | ' int2str(ref)], ...
                'NDI''s display form, as ndi.element/elementstring writes it');
            [n, r, form] = ndi.vintage.elementNameReference(lid);
            testCase.verifyEqual(n, name);
            testCase.verifyEqual(r, double(ref));
            testCase.verifyEqual(form, 'display');
        end

        function testTheSophCaseIsThreeIdentifiers(testCase)
            % the name alone is not unique: leftcortex n-trodes 1, 2 and 3
            lids = arrayfun(@(k) ndi.vintage.elementLocalIdentifier('leftcortex', k), ...
                1:3, 'UniformOutput', false);
            testCase.verifyEqual(lids, {'leftcortex | 1', 'leftcortex | 2', 'leftcortex | 3'});
            testCase.verifyNumElements(unique(lids), 3);
        end

        function testAReferenceGivenAsText(testCase)
            [lid, ok] = ndi.vintage.elementLocalIdentifier('lc', '2');
            testCase.verifyTrue(ok);
            testCase.verifyEqual(lid, 'lc | 2');
        end

        function testNoReferenceIsTheNameAlone(testCase)
            [lid, ok] = ndi.vintage.elementLocalIdentifier('rayostim', []);
            testCase.verifyTrue(ok);
            testCase.verifyEqual(lid, 'rayostim');
            [n, r, form] = ndi.vintage.elementNameReference(lid);
            testCase.verifyEqual(n, 'rayostim');
            testCase.verifyEmpty(r);
            testCase.verifyEqual(form, 'name');
            % a name holding ' | ' but no integer after the last one is a name
            [lid, ok] = ndi.vintage.elementLocalIdentifier('a | b', []);
            testCase.verifyTrue(ok);
            testCase.verifyEqual(ndi.vintage.elementNameReference(lid), 'a | b');
        end

        function testWhatCannotBeReadBackIsRefused(testCase)
            % with no reference, a name that reads as a pair; a reference
            % that is not an integer; no name
            cases = {{'ctx | 2', []}, {'ctx (ref 2)', []}, {'ctx', 2.5}, ...
                {'ctx', 'two'}, {'ctx', NaN}, {'', 1}};
            for k = 1:numel(cases)
                [lid, ok] = ndi.vintage.elementLocalIdentifier(cases{k}{:});
                testCase.verifyFalse(ok, sprintf('case %d', k));
                testCase.verifyEqual(lid, '', sprintf('case %d', k));
            end
        end

        function testTheOldFormIsStillRead(testCase)
            % migrated before 2026-10-26: '%s (ref %s)'
            [n, r, form] = ndi.vintage.elementNameReference('electrode16 (ref 1)');
            testCase.verifyEqual(n, 'electrode16');
            testCase.verifyEqual(r, 1);
            testCase.verifyEqual(form, 'ref');
            % a name holding ' | ' in the old form: it ends in ')', so it is
            % never read as the display form
            [n, r] = ndi.vintage.elementNameReference('a | 4 (ref 2)');
            testCase.verifyEqual(n, 'a | 4');
            testCase.verifyEqual(r, 2);
            % a reference that was not a number stays text
            [n, r] = ndi.vintage.elementNameReference('ctx (ref A)');
            testCase.verifyEqual(n, 'ctx');
            testCase.verifyEqual(r, 'A');
        end

        function testElementFieldsReadsBothForms(testCase)
            % the 1 -> N read: name and reference out of the entity
            testCase.assumeTrue(~isempty(getenv('DID_SCHEMA_PATH')), ...
                'DID_SCHEMA_PATH is not set (ndi.v2.vocabQuery reads it)');
            S = ndi.unittest.vintage.FakeFileSession({}, ...
                containers.Map('KeyType', 'char', 'ValueType', 'char'));
            lids = {'p | q (ref 2) | 5', 'electrode16 (ref 1)', 'rayostim'};
            wantName = {'p | q (ref 2)', 'electrode16', 'rayostim'};
            wantRef = {5, 1, []};
            for k = 1:numel(lids)
                doc.document_properties = struct( ...
                    'base', struct('id', sprintf('el_%d', k)), ...
                    'document_class', struct('class_name', 'entity'), ...
                    'entity', struct('local_identifier', lids{k}));
                f = ndi.vintage.elementFields(doc, S);
                testCase.verifyEqual(f.name, wantName{k}, lids{k});
                testCase.verifyEqual(f.reference, wantRef{k}, lids{k});
            end
        end
    end
end
