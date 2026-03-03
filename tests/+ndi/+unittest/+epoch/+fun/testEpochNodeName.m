classdef testEpochNodeName < matlab.unittest.TestCase

    methods(Test)
        function testNormalEpochId(testCase)
            node = struct('epoch_id', 'epoch_4126958b19a21a41_c0d5efe3d3fa43c5', 'objectname', 'myobj');
            res = ndi.epoch.fun.epochNodeName(node);
            testCase.verifyEqual(res, {'myobj; 43c5'});
        end

        function testOtherEpochId(testCase)
            node = struct('epoch_id', 'some_other_epoch', 'objectname', 'myobj2');
            res = ndi.epoch.fun.epochNodeName(node);
            testCase.verifyEqual(res, {'myobj2; some_other_epoch'});
        end

        function testMultipleNodes(testCase)
            node1 = struct('epoch_id', 'epoch_4126958b19a21a41_c0d5efe3d3fa43c5', 'objectname', 'myobj');
            node2 = struct('epoch_id', 'some_other_epoch', 'objectname', 'myobj2');
            res = ndi.epoch.fun.epochNodeName([node1, node2]);
            testCase.verifyEqual(res, {'myobj; 43c5', 'myobj2; some_other_epoch'});
        end

        function testMissingObjectName(testCase)
            node = struct('epoch_id', 'epoch_4126958b19a21a41_c0d5efe3d3fa43c5');
            res = ndi.epoch.fun.epochNodeName(node);
            testCase.verifyEqual(res, {'unknown; 43c5'});
        end

        function testSingularResponse(testCase)
            node = struct('epoch_id', 'epoch_4126958b19a21a41_c0d5efe3d3fa43c5', 'objectname', 'myobj');
            res = ndi.epoch.fun.epochNodeName(node, 'singlularResponseIsNotCell', true);
            testCase.verifyEqual(res, 'myobj; 43c5');
        end

        function testSingularResponseWithMultipleNodes(testCase)
            node1 = struct('epoch_id', 'epoch_4126958b19a21a41_c0d5efe3d3fa43c5', 'objectname', 'myobj');
            node2 = struct('epoch_id', 'some_other_epoch', 'objectname', 'myobj2');
            res = ndi.epoch.fun.epochNodeName([node1, node2], 'singlularResponseIsNotCell', true);
            testCase.verifyEqual(res, {'myobj; 43c5', 'myobj2; some_other_epoch'});
        end

        function testProbeShortening(testCase)
            node = struct('epoch_id', 'some_epoch', 'objectname', 'probe: 123');
            res = ndi.epoch.fun.epochNodeName(node);
            testCase.verifyEqual(res, {'p:123; some_epoch'});
        end

        function testElementShortening(testCase)
            node = struct('epoch_id', 'some_epoch', 'objectname', 'element: 123');
            res = ndi.epoch.fun.epochNodeName(node);
            testCase.verifyEqual(res, {'e:123; some_epoch'});
        end

        function testEmptyNodes(testCase)
            nodes = struct('epoch_id', {}, 'objectname', {});
            res = ndi.epoch.fun.epochNodeName(nodes);
            testCase.verifyEqual(res, {});
        end
    end
end
