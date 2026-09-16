classdef RemoveOldTest < matlab.unittest.TestCase
    % REMOVEOLDTEST - Tests for ndi.fun.probe.import.jrclust.removeOld, which
    % undoes a previous import so a re-sorted probe can be imported again.
    %
    % These run headless against a mock session that records what was searched
    % for and what was removed.

    properties
        WorkDir string = ""
        S
    end

    methods (TestMethodSetup)
        function makeSession(testCase)
            testCase.WorkDir = string(tempname);
            mkdir(testCase.WorkDir);
            testCase.addTeardown(@() rmdir(testCase.WorkDir,'s'));
            testCase.S = ndi.unittest.fun.probe.import.jrclust.MockSession( ...
                char(testCase.WorkDir));
        end
    end

    methods (Test)
        function testNeuronsAndTheirElementsAreRemoved(testCase)
            jc = ndi.unittest.fun.probe.import.jrclust.MockDoc.clusters('cluster_doc','some-checksum');
            neuron = ndi.unittest.fun.probe.import.jrclust.MockDoc('neuron_doc', struct(), struct('element_id','elem1'));
            elementDocs = {ndi.unittest.fun.probe.import.jrclust.MockDoc('elem1'), ndi.unittest.fun.probe.import.jrclust.MockDoc('elem1_epoch')};

            % first search finds the neuron_extracellular docs, the second the
            % element (and its epoch) documents
            testCase.S.SearchResults = {{neuron}, elementDocs};

            ndi.fun.probe.import.jrclust.removeOld(testCase.S, jc);

            % three removals, in order: the element documents, the neuron
            % documents, then the cluster document itself
            testCase.verifyEqual(numel(testCase.S.Removed),3);
            testCase.verifyEqual(testCase.S.Removed{1}, elementDocs);
            testCase.verifyEqual(testCase.S.Removed{2}, {neuron});
            testCase.verifyEqual(testCase.S.Removed{3}, jc);
        end

        function testClusterDocumentWithoutNeuronsIsStillRemoved(testCase)
            jc = ndi.unittest.fun.probe.import.jrclust.MockDoc.clusters('cluster_doc','some-checksum');
            % no search results: nothing was ever imported from this document
            ndi.fun.probe.import.jrclust.removeOld(testCase.S, jc);

            testCase.verifyEqual(numel(testCase.S.Removed),1);
            testCase.verifyEqual(testCase.S.Removed{1}, jc);
        end

        function testNeuronWithoutAnElementIsRemoved(testCase)
            jc = ndi.unittest.fun.probe.import.jrclust.MockDoc.clusters('cluster_doc','some-checksum');
            neuron = ndi.unittest.fun.probe.import.jrclust.MockDoc('neuron_doc'); % no element_id dependency
            testCase.S.SearchResults = {{neuron}};

            ndi.fun.probe.import.jrclust.removeOld(testCase.S, jc);

            % the neuron document and the cluster document, no element search
            testCase.verifyEqual(numel(testCase.S.Removed),2);
            testCase.verifyEqual(testCase.S.Removed{1}, {neuron});
            testCase.verifyEqual(testCase.S.Removed{2}, jc);
        end
    end
end
