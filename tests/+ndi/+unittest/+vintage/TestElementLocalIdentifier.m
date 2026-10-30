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

        % ---- [element name and reference stored apart] (2026-10-29) and
        % [element name kept apart, base.name carried] (2026-10-30): the name
        % is entity.name; the reference is what follows [name ' | ']

        function testApartNameHoldingPipe(testCase)
            % a name holding ' | ' and ending in ' | <integer>': the known
            % name, not the last ' | ', decides where the reference starts
            [n, r, apart] = ndi.vintage.elementNameReferenceApart( ...
                'a | 4', 'a | 4 | 3');
            testCase.verifyTrue(apart);
            testCase.verifyEqual(n, 'a | 4');
            testCase.verifyEqual(r, 3);
            % the same name with no reference
            [n, r, apart] = ndi.vintage.elementNameReferenceApart('a | 4', 'a | 4');
            testCase.verifyTrue(apart);
            testCase.verifyEqual(n, 'a | 4');
            testCase.verifyEmpty(r);
        end

        function testApartTextReference(testCase)
            [n, r, apart] = ndi.vintage.elementNameReferenceApart('ctx', 'ctx | A2');
            testCase.verifyTrue(apart);
            testCase.verifyEqual(n, 'ctx');
            testCase.verifyEqual(r, 'A2');
            % text after the name that holds ' | ' stays whole
            [~, r] = ndi.vintage.elementNameReferenceApart('ctx', 'ctx | x | y');
            testCase.verifyEqual(r, 'x | y');
        end

        function testApartNonIntegerReference(testCase)
            [n, r, apart] = ndi.vintage.elementNameReferenceApart('ctx', 'ctx | 1.5');
            testCase.verifyTrue(apart);
            testCase.verifyEqual(n, 'ctx');
            testCase.verifyEqual(r, 1.5);
        end

        function testApartEmptyName(testCase)
            % an element with an empty name: no entity.name, identifier
            % ' | <reference>'
            [n, r, apart] = ndi.vintage.elementNameReferenceApart('', ' | 2');
            testCase.verifyTrue(apart);
            testCase.verifyEqual(n, '');
            testCase.verifyEqual(r, 2);
            [n, r] = ndi.vintage.elementNameReferenceApart([], ' | B');
            testCase.verifyEqual(n, '');
            testCase.verifyEqual(r, 'B');
        end

        function testApartOldEntityWithoutName(testCase)
            % migrated before the decision: no `name`; today's split
            [n, r, apart] = ndi.vintage.elementNameReferenceApart('', 'leftcortex | 2');
            testCase.verifyFalse(apart);
            testCase.verifyEqual(n, 'leftcortex');
            testCase.verifyEqual(r, 2);
            [n, r, apart] = ndi.vintage.elementNameReferenceApart([], 'electrode16 (ref 1)');
            testCase.verifyFalse(apart);
            testCase.verifyEqual(n, 'electrode16');
            testCase.verifyEqual(r, 1);
            [n, r] = ndi.vintage.elementNameReferenceApart('', 'rayostim');
            testCase.verifyEqual(n, 'rayostim');
            testCase.verifyEmpty(r);
        end

        function testApartOldEntityWhoseNameIsBaseName(testCase)
            % migrated 2026-10-27..29: `name` was the v1 base.name and does
            % not lead the identifier; the identifier alone is read
            [n, r, apart] = ndi.vintage.elementNameReferenceApart( ...
                'some base name', 'leftcortex | 3');
            testCase.verifyFalse(apart);
            testCase.verifyEqual(n, 'leftcortex');
            testCase.verifyEqual(r, 3);
        end

        function testApartOldRefFormAfterTheName(testCase)
            [n, r, apart] = ndi.vintage.elementNameReferenceApart( ...
                'x (ref 7)', 'x (ref 7) (ref 1)');
            testCase.verifyTrue(apart);
            testCase.verifyEqual(n, 'x (ref 7)');
            testCase.verifyEqual(r, 1);
        end

        function testApartAcceptsStrings(testCase)
            [n, r] = ndi.vintage.elementNameReferenceApart("ctx", "ctx | 4");
            testCase.verifyEqual(n, 'ctx');
            testCase.verifyEqual(r, 4);
        end

        function testElementFieldsReadsTheNameFirst(testCase)
            testCase.assumeTrue(~isempty(getenv('DID_SCHEMA_PATH')), ...
                'DID_SCHEMA_PATH is not set (ndi.v2.vocabQuery reads it)');
            S = ndi.unittest.vintage.FakeFileSession({}, ...
                containers.Map('KeyType', 'char', 'ValueType', 'char'));
            % {entity.name ([] = no field), local_identifier, name, reference}
            cases = {
                'a | 4',  'a | 4 | 3',       'a | 4',  3
                'ctx',    'ctx | A2',        'ctx',    'A2'
                'ctx',    'ctx | 1.5',       'ctx',    1.5
                [],       ' | 2',            '',       2
                [],       'leftcortex | 2',  'leftcortex', 2
                'base',   'leftcortex | 2',  'leftcortex', 2
                };
            for k = 1:size(cases, 1)
                ent = struct('local_identifier', cases{k, 2});
                if ~isempty(cases{k, 1})
                    ent.name = cases{k, 1};
                end
                doc.document_properties = struct( ...
                    'base', struct('id', sprintf('el_apart_%d', k)), ...
                    'document_class', struct('class_name', 'entity'), ...
                    'entity', ent);
                f = ndi.vintage.elementFields(doc, S);
                testCase.verifyEqual(f.name, cases{k, 3}, cases{k, 2});
                testCase.verifyEqual(f.reference, cases{k, 4}, cases{k, 2});
            end
        end
    end
end
