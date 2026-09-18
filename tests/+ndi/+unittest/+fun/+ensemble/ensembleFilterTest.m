classdef ensembleFilterTest < matlab.unittest.TestCase
    % ENSEMBLEFILTERTEST - Unit tests for ndi.fun.ensemble.filter
    %
    % Exercises the pure, in-memory neuron selection on an ensemble structure:
    % include/exclude by name, index, and id; an explicit Keep mask; the
    % include-union-then-exclude semantics; row/label subsetting; num_neurons
    % update; and error handling. No database is used.

    methods

        function E = makeEnsemble(~)
            % 4 neurons with distinct spike times; row i has i spikes.
            A = sparse(4,3);
            A(1,1)   = 11;
            A(2,1:2) = [21 22];
            A(3,1:3) = [31 32 33];
            A(4,1)   = 41;
            E = struct();
            E.activity = A;
            E.neuron_ids = {'id1','id2','id3','id4'};
            E.neuron_names = {'A','B','C','D'};
            E.epoch = 'epoch_1';
            E.info = struct('num_neurons', 4, 'value_type', 'spiketimes');
        end

    end

    methods (Test)

        function testIncludeNames(testCase)
            E = ndi.fun.ensemble.filter(testCase.makeEnsemble(), 'IncludeNames', {'B','D'});
            testCase.verifyEqual(E.neuron_ids, {'id2','id4'});
            testCase.verifyEqual(E.neuron_names, {'B','D'});
            testCase.verifyEqual(E.info.num_neurons, 2);
            testCase.verifyEqual(full(E.activity), [21 22; 41 0], ...
                'Kept rows and trimmed columns.');
        end

        function testExcludeNames(testCase)
            E = ndi.fun.ensemble.filter(testCase.makeEnsemble(), 'ExcludeNames', {'A'});
            testCase.verifyEqual(E.neuron_ids, {'id2','id3','id4'});
        end

        function testIncludeIndex(testCase)
            E = ndi.fun.ensemble.filter(testCase.makeEnsemble(), 'IncludeIndex', [1 3]);
            testCase.verifyEqual(E.neuron_ids, {'id1','id3'});
            testCase.verifyEqual(full(E.activity), [11 0 0; 31 32 33]);
        end

        function testExcludeIndex(testCase)
            E = ndi.fun.ensemble.filter(testCase.makeEnsemble(), 'ExcludeIndex', 2);
            testCase.verifyEqual(E.neuron_ids, {'id1','id3','id4'});
        end

        function testExcludeIds(testCase)
            E = ndi.fun.ensemble.filter(testCase.makeEnsemble(), 'ExcludeIds', {'id3'});
            testCase.verifyEqual(E.neuron_ids, {'id1','id2','id4'});
        end

        function testKeepLogicalMask(testCase)
            E = ndi.fun.ensemble.filter(testCase.makeEnsemble(), 'Keep', logical([1 0 1 0]));
            testCase.verifyEqual(E.neuron_ids, {'id1','id3'});
        end

        function testKeepIndexVector(testCase)
            E = ndi.fun.ensemble.filter(testCase.makeEnsemble(), 'Keep', [4 2]);
            % order follows the ensemble, not the Keep argument
            testCase.verifyEqual(E.neuron_ids, {'id2','id4'});
        end

        function testIncludeUnionThenExclude(testCase)
            E = ndi.fun.ensemble.filter(testCase.makeEnsemble(), ...
                'IncludeNames', {'A','B','C'}, 'ExcludeNames', {'B'});
            testCase.verifyEqual(E.neuron_ids, {'id1','id3'}, ...
                'Exclude should win over include.');
        end

        function testNoOptionsKeepsAll(testCase)
            E = ndi.fun.ensemble.filter(testCase.makeEnsemble());
            testCase.verifyEqual(E.neuron_ids, {'id1','id2','id3','id4'});
            testCase.verifyEqual(E.info.num_neurons, 4);
        end

        function testBadIndexErrors(testCase)
            testCase.verifyError(@() ndi.fun.ensemble.filter(testCase.makeEnsemble(), ...
                'IncludeIndex', 5), 'ndi:ensemble:filter:badIndex');
        end

        function testBadKeepMaskErrors(testCase)
            testCase.verifyError(@() ndi.fun.ensemble.filter(testCase.makeEnsemble(), ...
                'Keep', logical([1 0 1])), 'ndi:ensemble:filter:badKeep');
        end

    end
end
