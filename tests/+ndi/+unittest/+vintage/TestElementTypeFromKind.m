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
%     - a shared kind with no "element type" assertion (a probe that never
%       recorded, [clamp mode of unrecorded probe dropped], Jess Haley,
%       2026-11-03) -> the general v1 type: 'patch' for a patch electrode,
%       'sharp' for a sharp electrode (Decided by Jess Haley, 2026-11-06,
%       "Read back patch"); '' for a microscope, which has no general
%       registered v1 type.
%     - a shared kind with no "element type" assertion and one recording
%       or imaging mode on the element's recording observations -> the v1
%       type of that kind and mode ([recording mode terms], Jess Haley,
%       2026-11-01: "`ndi.vintage.elementTypeOf` reads kind plus mode").
%
%   See also ndi.vintage.elementTypeOf, ndi.vintage.elementTypeOfKind,
%   ndi.vintage.elementTypeOfKindAndMode.

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

        function testAnUnrecordedPatchOrSharpReadsItsGeneralType(testCase)
            % a migrated device that never recorded: its device kind, no
            % "element type" assertion, no recording observation
            rows = {
                'EMPTY:0000411', 'patch'
                'empty:0000411', 'patch'     % prefix case aside
                'EMPTY:0000412', 'sharp'};
            testCase.log(sprintf('DENOMINATOR: %d shared kind(s) with a general type', size(rows, 1)));
            for k = 1:size(rows, 1)
                [t, how] = ndi.vintage.elementTypeOf({kindAssertion('el_3', rows{k, 1})});
                testCase.verifyEqual(t, rows{k, 2}, rows{k, 1});
                testCase.verifyEqual(how, 'general type', rows{k, 1});
            end
            % a sorted-unit entity type does not override the device kind
            t = ndi.vintage.elementTypeOf({kindAssertion('el_3', 'EMPTY:0000411')}, ...
                struct('node', 'CL:0000000', 'name', 'cell'));
            testCase.verifyEqual(t, 'patch');
        end

        function testAnUnrecordedMicroscopeReadsEmpty(testCase)
            % no general registered v1 imaging type
            [t, how] = ndi.vintage.elementTypeOf({kindAssertion('el_3', 'OBI:0400169')});
            testCase.verifyEqual(t, '');
            testCase.verifyEqual(how, '');
        end

        function testTheGeneralTypesAreRegisteredV1ProbeTypes(testCase)
            % each general word is in NDI's v1 probe type list, and is a
            % type of the kind it stands for
            reg = jsondecode(fileread(fullfile(ndi.common.PathConstants.CommonFolder, ...
                'probe', 'probetype2object.json')));
            registered = {reg.type};
            nodes = {'EMPTY:0000411', 'EMPTY:0000412', 'OBI:0400169'};
            testCase.log(sprintf('DENOMINATOR: %d registered v1 probe type(s), %d shared kind(s)', ...
                numel(registered), numel(nodes)));
            testCase.assertNotEmpty(registered);
            for k = 1:numel(nodes)
                g = ndi.vintage.elementGeneralTypeOfKind(nodes{k});
                if isempty(g)
                    continue;
                end
                testCase.verifyTrue(any(strcmp(g, registered)), g);
            end
            testCase.verifyEqual(ndi.vintage.elementGeneralTypeOfKind('OBI:0400169'), '');
            testCase.verifyEqual(ndi.vintage.elementGeneralTypeOfKind(''), '');
            testCase.verifyEqual(ndi.vintage.elementGeneralTypeOfKind('wikidata:Q1952355'), '');
            % no registered imaging type is general: each names its mode
            imaging = registered(endsWith(registered, 'imaging'));
            testCase.verifyNotEmpty(imaging);
            testCase.verifyFalse(any(strcmp(imaging, 'imaging')));
        end

        function testTheGeneralTypesAgreeWithDidMatlab(testCase)
            testCase.assumeNotEmpty(which('did2.convert.elementGeneralTypeOfKind'), ...
                'did2.convert.elementGeneralTypeOfKind is not on the path');
            nodes = {'EMPTY:0000411', 'EMPTY:0000412', 'OBI:0400169', 'wikidata:Q1952355'};
            for k = 1:numel(nodes)
                testCase.verifyEqual(ndi.vintage.elementGeneralTypeOfKind(nodes{k}), ...
                    did2.convert.elementGeneralTypeOfKind(nodes{k}), nodes{k});
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

        function testASortedUnitReadsSpikesFromItsEntityType(testCase)
            % [cell spellings are one meaning], [cell spellings amended]
            % (did-schema did_v2_go_forward_class_audit.md, Decided by Jess
            % Haley, 2026-10-27): DID-matlab writes no "element type"
            % assertion for a sorted unit; its entity type (`cell` or
            % `group`, by node) reads back as 'spikes'
            rows = {
                struct('node', 'CL:0000000', 'name', 'cell')
                struct('node', 'NCIT:C43359', 'name', 'Group')
                struct('node', 'NCIT:C43359', 'name', 'group')
                struct('node', '', 'name', 'cell')};
            testCase.log(sprintf('DENOMINATOR: %d unit entity type spelling(s)', numel(rows)));
            for k = 1:numel(rows)
                [t, how] = ndi.vintage.elementTypeOf({}, rows{k});
                testCase.verifyEqual(t, 'spikes', rows{k}.name);
                testCase.verifyEqual(how, 'entity type', rows{k}.name);
            end
            % the "element type" assertion still wins: an ensemble is a group
            [t, how] = ndi.vintage.elementTypeOf({typeAssertion('el_7', 'ensemble')}, rows{2});
            testCase.verifyEqual(t, 'ensemble');
            testCase.verifyEqual(how, 'element type');
            % any other entity type, and none, read '' as before
            for other = {struct('node', 'COB:0001300', 'name', 'device'), ''}
                [t, how] = ndi.vintage.elementTypeOf({}, other{1});
                testCase.verifyEqual(t, '');
                testCase.verifyEqual(how, '');
            end
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

        % ---- [recording mode terms] (Jess Haley, 2026-11-01): kind plus mode

        function testKindAndModeTable(testCase)
            % each registered type of a shared kind, from its kind and mode
            rows = {
                'EMPTY:0000411', 'OBI:0002185',   'patch-Vm'
                'EMPTY:0000411', 'OBI:0002182',   'patch-I'
                'EMPTY:0000411', 'OBI:0002179',   'patch-attached'
                'EMPTY:0000412', 'OBI:0002185',   'sharp-Vm'
                'EMPTY:0000412', 'OBI:0002182',   'sharp-Im'
                'OBI:0400169',   'OBI:0002437',   'wide-field-imaging'
                'OBI:0400169',   'FBbi:00000254', 'two-photon-imaging'
                'OBI:0400169',   'NCIT:C16856',   'one-photon-imaging'
                'OBI:0400169',   'EMPTY:0000300', 'brightfield-imaging'};
            testCase.log(sprintf('DENOMINATOR: %d (kind, mode) pair(s)', size(rows, 1)));
            for k = 1:size(rows, 1)
                testCase.verifyEqual(ndi.vintage.elementTypeOfKindAndMode( ...
                    rows{k, 1}, rows{k, 2}), rows{k, 3}, rows{k, 3});
            end
            % prefix case aside, as elementTypeOfKind compares
            testCase.verifyEqual(ndi.vintage.elementTypeOfKindAndMode( ...
                'empty:0000411', 'obi:0002185'), 'patch-Vm');
            % a mode of another kind, no mode, no kind: nothing
            testCase.verifyEqual(ndi.vintage.elementTypeOfKindAndMode( ...
                'EMPTY:0000411', 'OBI:0002437'), '');
            testCase.verifyEqual(ndi.vintage.elementTypeOfKindAndMode('EMPTY:0000411', ''), '');
            testCase.verifyEqual(ndi.vintage.elementTypeOfKindAndMode('', 'OBI:0002185'), '');
            % a kind with one type is not read here (elementTypeOfKind reads it)
            testCase.verifyEqual(ndi.vintage.elementTypeOfKindAndMode( ...
                'wikidata:Q1952355', 'OBI:0002185'), '');
        end

        function testKindAndModeTypesAreRegisteredProbeTypes(testCase)
            % every type the table reads back is a type NDI can build
            % (probetype2object.json), and has the kind DID-matlab gives it
            f = fullfile(ndi.toolboxdir, 'ndi_common', 'probe', 'probetype2object.json');
            j = jsondecode(fileread(f));
            registered = {j.type};
            pairs = {
                'EMPTY:0000411', {'OBI:0002185', 'OBI:0002182', 'OBI:0002179'}
                'EMPTY:0000412', {'OBI:0002185', 'OBI:0002182'}
                'OBI:0400169',   {'OBI:0002437', 'FBbi:00000254', 'NCIT:C16856', 'EMPTY:0000300'}};
            n = 0;
            for k = 1:size(pairs, 1)
                for m = 1:numel(pairs{k, 2})
                    t = ndi.vintage.elementTypeOfKindAndMode(pairs{k, 1}, pairs{k, 2}{m});
                    n = n + 1;
                    testCase.verifyTrue(any(strcmp(registered, t)), ...
                        sprintf('%s + %s -> "%s", not in probetype2object.json', ...
                        pairs{k, 1}, pairs{k, 2}{m}, t));
                    if ~isempty(which('did2.convert.elementDeviceKind'))
                        kind = did2.convert.elementDeviceKind(t);
                        testCase.verifyEqual(kind.node, pairs{k, 1}, t);
                    end
                end
            end
            testCase.log(sprintf('DENOMINATOR: %d (kind, mode) pair(s) checked', n));
        end

        function testSharedKindReadsItsMode(testCase)
            cc = struct('node', 'OBI:0002185', 'name', 'current clamp assay');
            vc = struct('node', 'OBI:0002182', 'name', 'voltage clamp assay');
            patch = kindAssertion('el_m', 'EMPTY:0000411');
            [t, how, needsMode] = ndi.vintage.elementTypeOf({patch}, '', {cc});
            testCase.verifyEqual(t, 'patch-Vm');
            testCase.verifyEqual(how, 'device kind and mode');
            testCase.verifyTrue(needsMode);
            % one mode on every epoch's observation: still that type
            testCase.verifyEqual(ndi.vintage.elementTypeOf({patch}, '', {vc, vc, vc}), 'patch-I');
            % a node alone is a mode too
            testCase.verifyEqual(ndi.vintage.elementTypeOf( ...
                {kindAssertion('el_m', 'EMPTY:0000412')}, '', {'OBI:0002182'}), 'sharp-Im');
            % a microscope, which has no general type, reads its imaging mode
            [t, how] = ndi.vintage.elementTypeOf({kindAssertion('el_m', 'OBI:0400169')}, '', ...
                {struct('node', 'FBbi:00000254', 'name', 'two-photon laser scanning microscopy')});
            testCase.verifyEqual(t, 'two-photon-imaging');
            testCase.verifyEqual(how, 'device kind and mode');
            % a method that is no mode of the kind is ignored
            testCase.verifyEqual(ndi.vintage.elementTypeOf({patch}, '', ...
                {struct('node', 'OBI:0002437', 'name', 'widefield microscopy assay'), cc}), 'patch-Vm');
        end

        function testTheElementTypeAssertionStillWins(testCase)
            % while DID-matlab writes "element type", it is read first
            cc = struct('node', 'OBI:0002185', 'name', 'current clamp assay');
            [t, how, needsMode] = ndi.vintage.elementTypeOf( ...
                {typeAssertion('el_w', 'patch-I'), kindAssertion('el_w', 'EMPTY:0000411')}, '', {cc});
            testCase.verifyEqual(t, 'patch-I');
            testCase.verifyEqual(how, 'element type');
            testCase.verifyFalse(needsMode);
        end

        function testNoSingleModeReadsAsBefore(testCase)
            cc = struct('node', 'OBI:0002185', 'name', 'current clamp assay');
            vc = struct('node', 'OBI:0002182', 'name', 'voltage clamp assay');
            patch = kindAssertion('el_n', 'EMPTY:0000411');
            % two different modes rebuild no single v1 word: the general type
            [t, how] = ndi.vintage.elementTypeOf({patch}, '', {cc, vc});
            testCase.verifyEqual(t, 'patch');
            testCase.verifyEqual(how, 'general type');
            % no recording ([clamp mode of unrecorded probe dropped])
            [t, how, needsMode] = ndi.vintage.elementTypeOf({patch}, '', {});
            testCase.verifyEqual(t, 'patch');
            testCase.verifyEqual(how, 'general type');
            testCase.verifyTrue(needsMode);
            % a microscope with no single mode reads '' as before
            testCase.verifyEqual(ndi.vintage.elementTypeOf( ...
                {kindAssertion('el_n', 'OBI:0400169')}, '', {}), '');
            % a kind with one type needs no mode
            [t, ~, needsMode] = ndi.vintage.elementTypeOf({kindAssertion('el_n', 'NCIT:C88166')});
            testCase.verifyEqual(t, 'accelerometer');
            testCase.verifyFalse(needsMode);
        end

        function testElementFieldsReadsTheModeOfItsObservations(testCase)
            % the 1 -> N read: an element whose type the assertions do not
            % settle reads the mode on the observations it made
            testCase.assumeTrue(~isempty(getenv('DID_SCHEMA_PATH')), ...
                'DID_SCHEMA_PATH is not set (ndi.v2.vocabQuery reads it)');
            elementId = 'el_fields_mode';
            kind = kindAssertion(elementId, 'EMPTY:0000412');
            obs = struct('base', struct('id', 'obs_1'), ...
                'document_class', struct('class_name', 'observation'), ...
                'interaction', struct('method', struct('term', ...
                    struct('node', 'OBI:0002182', 'name', 'voltage clamp assay'), ...
                    'parameters', [])), ...
                'depends_on', struct('name', {'entity_id', 'instrument_id'}, ...
                    'document_id', {'specimen_1', elementId}));
            S = ndi.unittest.vintage.FakeSearchSession(@(q) modeAnswer(q, obs, kind));
            doc.document_properties = struct( ...
                'base', struct('id', elementId), ...
                'document_class', struct('class_name', 'entity'), ...
                'entity', struct('local_identifier', 'sharp1 | 1', 'name', 'sharp1'));
            f = ndi.vintage.elementFields(doc, S);
            testCase.verifyEqual(f.type, 'sharp-Im');
            testCase.verifyEqual(f.subject_id, 'specimen_1');
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

function d = modeAnswer(q, obs, kind)
% a session answering by the values a query carries: the observations the
% element made, its device-kind assertion, and nothing else
vals = queryValues(q.searchstructure);
if any(strcmp(vals, 'instrument_id'))
    d = {obs};
elseif any(strcmp(vals, 'NCIT:C178920')) || any(strcmp(vals, 'Equipment Type'))
    d = {kind};
else
    d = {};
end
end

function vals = queryValues(ss)
% every text value a query carries, nested queries included (as
% ndi.unittest.vintage.TestElementDocsBothVintages reads them)
vals = {};
for k = 1:numel(ss)
    for f = {'param1', 'param2'}
        v = ss(k).(f{1});
        if ischar(v) || (isstring(v) && isscalar(v))
            vals{end+1} = char(v); %#ok<AGROW>
        elseif iscell(v)
            vals = [vals, cellfun(@char, v(cellfun(@(x) ischar(x) || isstring(x), v)), ...
                'UniformOutput', false)]; %#ok<AGROW>
        elseif isstruct(v) && isfield(v, 'param1')
            vals = [vals, queryValues(v)]; %#ok<AGROW>
        end
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
