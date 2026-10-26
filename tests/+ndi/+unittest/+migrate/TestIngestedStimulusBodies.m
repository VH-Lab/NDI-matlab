classdef TestIngestedStimulusBodies < matlab.unittest.TestCase
%TESTINGESTEDSTIMULUSBODIES ndi.migrate.internal.ingestedStimulusBodies: a v1
%   daqmetadatareader_epochdata_ingested becomes an `opaque_body` of its
%   epoch's stimulus-presentation manipulation, joined by session and epoch
%   id; with no single match it stays v1. Decided by Jess Haley, 2026-10-26
%   [ingested stimulus file is a body of the presentation] (did-schema
%   V_eta_go_forward_class_audit.md).
%
%   The fixture is transcribed from a real Dab document
%   (4126900b4ee8eb82_c0c10c1d0f2bef83: epoch t00074, data.bin on ndicloud).

    methods (TestClassSetup)
        function needSchema(testCase)
            testCase.assumeTrue(~isempty(which('did2.schema.cache')) && ...
                did2.schema.cache.shared().hasClass('entity'), ...
                'no V_eta schema set (did-schema #88, `entity`) where did2.schema.cache looks');
        end
    end

    methods (Test)
        function testItBecomesTheBodyOfItsEpochsPresentation(testCase)
            [bodies, consumed, r] = ndi.migrate.internal.ingestedStimulusBodies( ...
                {ingestedDoc()}, presentation('pres_74', 't00074'), {readerDoc()});
            testCase.verifyNumElements(bodies, 1);
            b = bodies{1};
            testCase.verifyEqual(b.document_class.class_name, 'opaque_body');
            testCase.verifyEqual(b.base.id, '4126900b4ee8eb82_c0c10c1d0f2bef83', ...
                'the v1 id is kept');
            testCase.verifyEqual(depValue(b, 'owner_id'), 'pres_74');
            testCase.verifyEqual(b.data_body.filename, 'data.bin');
            testCase.verifyEqual(b.data_body.compression, 'gzip');
            testCase.verifyEqual(char(b.data_body.format.node), 'EMPTY:0000367', ...
                '[NDI binary format]');
            testCase.verifySubstring(b.data_body.description, 't00074');
            testCase.verifySubstring(b.data_body.description, '4126900ae50fa7e6_40de2d125a0b8212');
            testCase.verifySubstring(b.data_body.description, 'ndi.daq.metadatareader.NewStimStims');
            % carried as attached: body_data_0 with data.bin's locations
            v1 = ingestedDoc();
            testCase.verifyEqual(b.files.file_info.name, 'body_data_0');
            testCase.verifyEqual(b.files.file_info.locations, v1.files.file_info.locations);
            testCase.verifyEqual(consumed, {'4126900b4ee8eb82_c0c10c1d0f2bef83'});
            testCase.verifyEqual(r.ingested_seen, 1);
            testCase.verifyEqual(r.converted, 1);
            cache = did2.schema.cache.shared();
            restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
            testCase.verifyWarningFree(@() cache.validateDocument(b), ...
                'the opaque_body does not validate');
        end

        function testNoMatchingPresentationLeavesItV1(testCase)
            % another epoch, and another session
            p = [presentation('pres_75', 't00075'), presentation('pres_x', 't00074', 'sess_other')];
            [bodies, consumed, r] = ndi.migrate.internal.ingestedStimulusBodies( ...
                {ingestedDoc()}, p, {});
            testCase.verifyEmpty(bodies);
            testCase.verifyEmpty(consumed);
            testCase.verifyEqual(r.left_no_presentation, 1);
        end

        function testTwoPresentationsInTheEpochLeaveItV1(testCase)
            p = [presentation('pres_a', 't00074'), presentation('pres_b', 't00074')];
            [bodies, ~, r] = ndi.migrate.internal.ingestedStimulusBodies( ...
                {ingestedDoc()}, p, {});
            testCase.verifyEmpty(bodies);
            testCase.verifyEqual(r.left_several_presentations, 1);
        end

        function testSomethingTheBodyDoesNotWriteLeavesItV1(testCase)
            d = ingestedDoc();
            d.depends_on(end+1) = struct('name', 'element_id', 'value', 'el_1');
            [bodies, ~, r] = ndi.migrate.internal.ingestedStimulusBodies( ...
                {d}, presentation('pres_74', 't00074'), {});
            testCase.verifyEmpty(bodies);
            testCase.verifyEqual(r.left_unplaced, 1);
            testCase.verifySubstring(r.left_reasons{1}.reason, 'element_id');
        end

        function testOtherDocumentsAreNotTouched(testCase)
            other = struct('document_class', struct('class_name', 'stimulus_presentation'), ...
                'base', struct('id', 'x', 'session_id', 'sess_dab'));
            [bodies, ~, r] = ndi.migrate.internal.ingestedStimulusBodies( ...
                {other}, presentation('pres_74', 't00074'), {});
            testCase.verifyEmpty(bodies);
            testCase.verifyEqual(r.documents_inspected, 1);
            testCase.verifyEqual(r.ingested_seen, 0);
        end
    end
end

function d = ingestedDoc()
d = struct();
d.base = struct('id', '4126900b4ee8eb82_c0c10c1d0f2bef83', ...
    'session_id', 'sess_dab', 'name', '', 'datestamp', '2024-03-22T15:41:56.036Z');
d.daqmetadatareader_epochdata_ingested = struct();
d.depends_on = struct('name', 'daqmetadatareader_id', ...
    'value', '4126900ae50fa7e6_40de2d125a0b8212');
d.document_class = struct('class_name', 'daqmetadatareader_epochdata_ingested', ...
    'property_list_name', 'daqmetadatareader_epochdata_ingested', 'class_version', 1);
d.epochid = struct('epochid', 't00074');
d.files = struct('file_list', {{'data.bin'}}, 'file_info', struct('name', 'data.bin', ...
    'locations', struct('delete_original', 0, 'uid', '4126900dfbac8568_c0c719704d6851ae', ...
    'location', 'ndic://66140c237dbc358954ddffb9/4126900dfbac8568_c0c719704d6851ae', ...
    'parameters', '', 'location_type', 'ndicloud', 'ingest', 0)));
end

function d = readerDoc()
d = struct();
d.base = struct('id', '4126900ae50fa7e6_40de2d125a0b8212', 'session_id', 'sess_dab');
d.document_class = struct('class_name', 'daqmetadatareader');
d.daqmetadatareader = struct('ndi_daqmetadatareader_class', ...
    'ndi.daq.metadatareader.NewStimStims', 'tab_separated_file_parameter', '');
end

function p = presentation(id, epochId, sessionId)
if nargin < 3; sessionId = 'sess_dab'; end
p = struct('session_id', sessionId, 'epoch_id', epochId, 'id', id);
end

function v = depValue(b, name)
v = '';
for k = 1:numel(b.depends_on)
    d = b.depends_on(k);
    if ~strcmp(d.name, name); continue; end
    if isfield(d, 'document_id'); v = d.document_id; else; v = d.value; end
    if iscell(v) && ~isempty(v); v = v{1}; end
    return;
end
end
