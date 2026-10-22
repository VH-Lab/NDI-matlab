classdef TestEpochSeries < matlab.unittest.TestCase
%TESTEPOCHSERIES ndi.vintage.epochSeries reads a derived element's epochs from
%   the DISSOLVED element_epoch shape (Decided by Jess Haley, 2026-10-22 [epoch
%   dissolution before merge]): an observation of the element, anchored by a
%   relative_time_reference (clock, start, end) onto the epoch entity whose
%   local_identifier is the v1 epoch id. The fixtures are the shape
%   did2.convert.resolveEpochProbemap emits (DID-matlab
%   testResolveEpochProbemap/testTheTrainIsAnchoredToItsEpochWithItsOwnExtent).

    methods (Test)

        function testOneTrainGivesOneEpochRow(testCase)
            [obs, lookup] = fixture('t00006', 'epoch', 'dev_local_time', 0, 579.85);
            s = ndi.vintage.epochSeries({obs}, lookup);
            testCase.assertNumElements(s, 1);
            testCase.verifyEqual(s.epoch_id, 't00006');
            testCase.verifyEqual(s.epoch_clock{1}.type, 'dev_local_time');
            testCase.verifyEqual(s.t0_t1{1}, [0 579.85], 'AbsTol', 1e-12);
            testCase.verifyEqual(s.epoch_doc_id, 'epoch_1');
        end

        function testTheRenamedEpochTypeIsStillAnEpoch(testCase)
            % L3 (Jess Haley, 2026-10-22): the epoch type becomes EMPTY:0000383
            % 'recording epoch'; the reader must not go empty when it lands.
            [obs, lookup] = fixture('t00007', 'recording epoch', 'dev_local_time', 1, 2);
            s = ndi.vintage.epochSeries({obs}, lookup);
            testCase.verifyEqual(numel(s), 1);
            testCase.verifyEqual(s.epoch_id, 't00007');
        end

        function testAnAnchorOntoTheSessionIsNotAnEpoch(testCase)
            [obs, lookup] = fixture('ignored', 'session', 'dev_local_time', 0, 1);
            s = ndi.vintage.epochSeries({obs}, lookup);
            testCase.verifyEmpty(s);
        end

        function testARelationOnlyAnchorIsNotASeries(testCase)
            % "during the epoch" with no clock or start: no extent to report
            [obs, lookup] = fixture('t00008', 'epoch', '', [], []);
            s = ndi.vintage.epochSeries({obs}, lookup);
            testCase.verifyEmpty(s);
        end

        function testNoObservationsIsEmptyNotAnError(testCase)
            s = ndi.vintage.epochSeries({}, @(id) []);
            testCase.verifyEmpty(s);
        end

    end
end

function [obs, lookup] = fixture(epochString, typeName, clockName, t0, t1)
obs = struct();
obs.document_class = struct('class_name', 'observation');
obs.base = struct('id', 'ee_1', 'session_id', 'sess');
obs.depends_on = [struct('name', 'entity_id', 'value', 'el_neuron'), ...
    struct('name', 'time_reference_id', 'value', 'tr_1')];
v = struct();
if ~isempty(clockName)
    v.clock = struct('node', '', 'name', clockName);
    v.start = struct('seconds', t0);
    v.end = struct('seconds', t1);
else
    v.relation = struct('node', 'time:intervalDuring', 'name', 'intervalDuring');
end
tr = struct();
tr.document_class = struct('class_name', 'relative_time_reference');
tr.base = struct('id', 'tr_1');
tr.depends_on = struct('name', 'referent_id', 'value', 'epoch_1');
tr.relative_time_reference = struct('value', v);
ep = struct();
ep.document_class = struct('class_name', 'entity');
ep.base = struct('id', 'epoch_1');
ep.depends_on = struct('name', {}, 'value', {});
ep.entity = struct('type', struct('node', '', 'name', typeName), ...
    'local_identifier', epochString);
m = containers.Map({'tr_1', 'epoch_1'}, {tr, ep});
lookup = @(id) lookupIn(m, id);
end

function p = lookupIn(m, id)
p = [];
if isKey(m, id); p = m(id); end
end
