classdef TestElementTypeFromKind < matlab.unittest.TestCase
%TESTELEMENTTYPEFROMKIND A migrated element's v1 type reads back from its device kind.
%
%   DID-matlab PR #304 stops writing the "element type" assertion where the
%   device kind (variable NCIT:C178920 "Equipment Type") alone rebuilds the
%   v1 type (did-schema V_eta_go_forward_class_audit.md, [element type is a
%   device kind term], [element types batch 1] .. [element types batch 4],
%   Decided by Jess Haley). The reader:
%     - only a device-kind assertion -> the one v1 type of that kind;
%     - both assertions -> the "element type" assertion wins;
%     - a shared kind (patch / sharp electrode, microscope) with no
%       "element type" assertion -> '', as an element with no assertion
%       read before.
%
%   See also ndi.vintage.elementTypeOf, ndi.vintage.elementTypeOfKind.

    methods (Test)

        function testOnlyTheKindReadsBackItsType(testCase)
            % one row per kind with exactly one v1 type
            rows = {
                'wikidata:Q1952355', 'n-trode'
                'Wikidata:Q1952355', 'n-trode'          % prefix case aside
                'NCIT:C49936',       'electrode-$'
                'EMPTY:0000414',     'lick-spout'
                'EMPTY:0000415',     'reward-well'
                'NCIT:C50343',       'intraoral-cannula'
                'NCIT:C50358',       'optogenetic-fiber'
                'OBI:0003806',       'ecg'
                'wikidata:Q4531135', 'eeg'
                'NCIT:C88166',       'accelerometer'
                'NCIT:C50059',       'thermometer'
                'NCIT:C224112',      'ppg'};
            testCase.log(sprintf('DENOMINATOR: %d kind(s) with one v1 type', size(rows, 1)));
            for k = 1:size(rows, 1)
                a = kindAssertion('el_1', rows{k, 1});
                [t, how] = ndi.vintage.elementTypeOf({a});
                testCase.verifyEqual(t, rows{k, 2}, rows{k, 1});
                testCase.verifyEqual(how, 'device kind', rows{k, 1});
            end
        end

        function testTheElementTypeAssertionWins(testCase)
            % both, in either order: the "element type" assertion is read
            % (an element migrated before #304 has both)
            a = typeAssertion('el_1', 'n-trode');
            b = kindAssertion('el_1', 'NCIT:C88166');   % accelerometer
            [t, how] = ndi.vintage.elementTypeOf({b, a});
            testCase.verifyEqual(t, 'n-trode');
            testCase.verifyEqual(how, 'element type');
            t = ndi.vintage.elementTypeOf({a, b});
            testCase.verifyEqual(t, 'n-trode');
            % a shared kind keeps its assertion: patch-Vm, not ''
            t = ndi.vintage.elementTypeOf({kindAssertion('el_2', 'EMPTY:0000411'), ...
                typeAssertion('el_2', 'patch-Vm')});
            testCase.verifyEqual(t, 'patch-Vm');
        end

        function testASharedKindAloneReadsEmpty(testCase)
            for node = {'EMPTY:0000411', 'EMPTY:0000412', 'OBI:0400169'}
                [t, how] = ndi.vintage.elementTypeOf({kindAssertion('el_3', node{1})});
                testCase.verifyEqual(t, '', node{1});
                testCase.verifyEqual(how, '', node{1});
            end
        end

        function testNothingReadsEmpty(testCase)
            [t, how] = ndi.vintage.elementTypeOf({});
            testCase.verifyEqual(t, '');
            testCase.verifyEqual(how, '');
            % an unknown kind, and an assertion under another variable
            other = kindAssertion('el_4', 'NCIT:C88166');
            other.statement.variable = struct('node', 'NCIT:C13717', 'name', 'Anatomic Site');
            t = ndi.vintage.elementTypeOf({kindAssertion('el_4', 'NCIT:C0000000'), other});
            testCase.verifyEqual(t, '');
        end

        function testAKindByLabelOnly(testCase)
            % a variable with no node is compared by its label
            a = kindAssertion('el_5', 'OBI:0003806');
            a.statement.variable = struct('node', '', 'name', 'Equipment Type');
            testCase.verifyEqual(ndi.vintage.elementTypeOf({a}), 'ecg');
        end

        function testDocumentPropertiesWrapperIsRead(testCase)
            % the shape a session search returns, as a struct
            d.document_properties = kindAssertion('el_6', 'NCIT:C50059');
            testCase.verifyEqual(ndi.vintage.elementTypeOf({d}), 'thermometer');
        end

        function testTheMirrorAgreesWithDidMatlab(testCase)
            % the mirror stands in for did2.convert.elementTypeOfKind until
            % DID-matlab #304 is on the path NDI CI checks out; when it is,
            % the two must give the same answer for every kind
            testCase.assumeNotEmpty(which('did2.convert.elementTypeOfKind'), ...
                'did2.convert.elementTypeOfKind is not on the path (DID-matlab #304 not checked out)');
            [~, ~, types] = did2.convert.elementDeviceKind('');
            nodes = unique(types(:, 2));
            testCase.log(sprintf('DENOMINATOR: %d kind node(s) from did2.convert.elementDeviceKind', numel(nodes)));
            testCase.assertNotEmpty(nodes);
            for k = 1:numel(nodes)
                [d, src] = ndi.vintage.elementTypeOfKind(nodes{k});
                testCase.verifyEqual(src, 'did2');
                [m, msrc] = ndi.vintage.elementTypeOfKind(nodes{k}, true);
                testCase.verifyEqual(msrc, 'mirror');
                testCase.verifyEqual(m, d, nodes{k});
            end
        end

        function testTheMirrorTable(testCase)
            % the mirror on its own, whatever is on the path
            testCase.verifyEqual(ndi.vintage.elementTypeOfKind('wikidata:Q1952355', true), 'n-trode');
            testCase.verifyEqual(ndi.vintage.elementTypeOfKind('OBI:0400169', true), '');
            testCase.verifyEqual(ndi.vintage.elementTypeOfKind('', true), '');
            testCase.verifyEqual(ndi.vintage.elementTypeOfKind('ncit:C224112', true), 'ppg');
            % [stimulator is SNOMED CT Stimulator], DID-matlab #304
            testCase.verifyEqual(ndi.vintage.elementTypeOfKind('SNOMEDCT:36645008', true), 'stimulator');
        end
    end
end

function a = typeAssertion(entityId, type)
% the "element type" assertion migrators_j.element writes (before #304, always)
a = assertionBody(entityId, struct('node', '', 'name', 'element type'), ...
    struct('node', '', 'name', type));
end

function a = kindAssertion(entityId, node)
% the device-kind assertion: variable NCIT:C178920 "Equipment Type"
a = assertionBody(entityId, struct('node', 'NCIT:C178920', 'name', 'Equipment Type'), ...
    struct('node', node, 'name', ''));
end

function a = assertionBody(entityId, variable, value)
a = struct();
a.document_class = struct('class_name', 'assertion', 'superclasses', ...
    struct('class_name', {'statement', 'base', 'term', 'value', 'data'}));
a.depends_on = struct('name', 'entity_id', 'document_id', entityId);
a.base = struct('id', ['a_' entityId '_' strrep(value.node, ':', '')]);
a.statement = struct('variable', variable);
a.term = struct('value', value);
end
