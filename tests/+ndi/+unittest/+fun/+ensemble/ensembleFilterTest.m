classdef ensembleFilterTest < matlab.unittest.TestCase
    % ENSEMBLEFILTERTEST - Unit tests for ndi.fun.ensemble.filter
    %
    % Exercises the pure, in-memory neuron selection: include/exclude by name,
    % index, and id; an explicit Keep mask; the include-union-then-exclude
    % semantics; row/label subsetting; num_neurons update; and error handling.
    % No database is used.

    methods

        function [A, ids, names, info] = makeEnsemble(~)
            % 4 neurons with distinct spike times; row i has i spikes.
            A = sparse(4,3);
            A(1,1)   = 11;
            A(2,1:2) = [21 22];
            A(3,1:3) = [31 32 33];
            A(4,1)   = 41;
            ids   = {'id1','id2','id3','id4'};
            names = {'A','B','C','D'};
            info  = struct('num_neurons', 4, 'value_type', 'spiketimes');
        end

    end

    methods (Test)

        function testIncludeNames(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            [A2, ids2, names2, info2] = ndi.fun.ensemble.filter(A, ids, names, info, ...
                'IncludeNames', {'B','D'});
            testCase.verifyEqual(ids2, {'id2','id4'});
            testCase.verifyEqual(names2, {'B','D'});
            testCase.verifyEqual(info2.num_neurons, 2);
            testCase.verifyEqual(full(A2), [21 22; 41 0], 'Kept rows and trimmed columns.');
        end

        function testExcludeNames(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            [~, ids2] = ndi.fun.ensemble.filter(A, ids, names, info, 'ExcludeNames', {'A'});
            testCase.verifyEqual(ids2, {'id2','id3','id4'});
        end

        function testIncludeIndex(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            [A2, ids2] = ndi.fun.ensemble.filter(A, ids, names, info, 'IncludeIndex', [1 3]);
            testCase.verifyEqual(ids2, {'id1','id3'});
            testCase.verifyEqual(full(A2), [11 0 0; 31 32 33]);
        end

        function testExcludeIndex(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            [~, ids2] = ndi.fun.ensemble.filter(A, ids, names, info, 'ExcludeIndex', 2);
            testCase.verifyEqual(ids2, {'id1','id3','id4'});
        end

        function testIncludeAndExcludeIds(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            [~, ids2] = ndi.fun.ensemble.filter(A, ids, names, info, 'ExcludeIds', {'id3'});
            testCase.verifyEqual(ids2, {'id1','id2','id4'});
        end

        function testKeepLogicalMask(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            [~, ids2] = ndi.fun.ensemble.filter(A, ids, names, info, ...
                'Keep', logical([1 0 1 0]));
            testCase.verifyEqual(ids2, {'id1','id3'});
        end

        function testKeepIndexVector(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            [~, ids2] = ndi.fun.ensemble.filter(A, ids, names, info, 'Keep', [4 2]);
            % order follows the ensemble, not the Keep argument
            testCase.verifyEqual(ids2, {'id2','id4'});
        end

        function testIncludeUnionThenExclude(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            [~, ids2] = ndi.fun.ensemble.filter(A, ids, names, info, ...
                'IncludeNames', {'A','B','C'}, 'ExcludeNames', {'B'});
            testCase.verifyEqual(ids2, {'id1','id3'}, ...
                'Exclude should win over include.');
        end

        function testNoOptionsKeepsAll(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            [~, ids2, ~, info2] = ndi.fun.ensemble.filter(A, ids, names, info);
            testCase.verifyEqual(ids2, ids);
            testCase.verifyEqual(info2.num_neurons, 4);
        end

        function testBadIndexErrors(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            testCase.verifyError(@() ndi.fun.ensemble.filter(A, ids, names, info, ...
                'IncludeIndex', 5), 'ndi:ensemble:filter:badIndex');
        end

        function testBadKeepMaskErrors(testCase)
            [A, ids, names, info] = testCase.makeEnsemble();
            testCase.verifyError(@() ndi.fun.ensemble.filter(A, ids, names, info, ...
                'Keep', logical([1 0 1])), 'ndi:ensemble:filter:badKeep');
        end

    end
end
