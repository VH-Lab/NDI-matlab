classdef SyncgraphMutationTest < matlab.unittest.TestCase
    % SYNCGRAPHMUTATIONTEST - regression tests for syncgraph removerule/removeepoch
    %
    % Both methods previously called setdiff with a single argument (removerule
    % via a misplaced closing paren, removeepoch by omitting the second operand)
    % and therefore threw "Not enough input arguments" on every call -- they were
    % dead on arrival. These tests confirm the repaired methods actually mutate
    % the graph.
    %
    % Constructed without a session so the (session-backed) cache calls are safe
    % no-ops.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testRemoveRuleDropsIndexedRule(testCase)
            sg = ndi.time.syncgraph();
            r1 = ndi.time.syncrule.filematch(struct('number_fullpath_matches', 2));
            r2 = ndi.time.syncrule.filematch(struct('number_fullpath_matches', 3));
            sg = sg.addrule(r1);
            sg = sg.addrule(r2);
            testCase.assertEqual(numel(sg.rules), 2);

            sg = sg.removerule(1);
            testCase.verifyEqual(numel(sg.rules), 1);
            % The surviving rule must be r2 (index 2), not r1.
            % ndi.time.syncrule/eq delegates to vlt.data.eqlen, which returns a
            % double 0/1 rather than a logical, and verifyTrue rejects a
            % non-logical actual value. Convert explicitly.
            testCase.verifyTrue(logical(sg.rules{1} == r2), ...
                'removerule(1) must leave r2, not r1, as the surviving rule.');
        end

        function testRemoveRuleDoesNotError(testCase)
            % Regression: the one-arg setdiff made this throw unconditionally.
            sg = ndi.time.syncgraph();
            sg = sg.addrule(ndi.time.syncrule.filematch());
            testCase.verifyWarningFree(@() sg.removerule(1));
        end

        function testRemoveEpochKeepsOtherObjects(testCase)
            sg = ndi.time.syncgraph();

            ginfo = struct();
            ginfo.nodes = struct('objectname', {'A', 'B', 'C'});
            ginfo.G = magic(3);
            ginfo.mapping = cell(3, 3);
            ginfo.syncRuleG = ones(3, 3);

            daq = struct('name', 'B'); % only .name is read by removeepoch

            ginfoOut = sg.removeepoch(daq, ginfo);

            testCase.verifyEqual(numel(ginfoOut.nodes), 2);
            testCase.verifyEqual({ginfoOut.nodes.objectname}, {'A', 'C'});
            testCase.verifyEqual(size(ginfoOut.G), [2 2]);
            testCase.verifyEqual(size(ginfoOut.mapping), [2 2]);
            testCase.verifyEqual(size(ginfoOut.syncRuleG), [2 2]);
            % The kept submatrix is rows/cols [1 3] of the original G.
            testCase.verifyEqual(ginfoOut.G, ginfo.G([1 3], [1 3]));
        end

        function testRemoveEpochNoMatchKeepsAll(testCase)
            sg = ndi.time.syncgraph();
            ginfo = struct();
            ginfo.nodes = struct('objectname', {'A', 'B'});
            ginfo.G = magic(2);
            ginfo.mapping = cell(2, 2);
            ginfo.syncRuleG = ones(2, 2);

            ginfoOut = sg.removeepoch(struct('name', 'Z'), ginfo);
            testCase.verifyEqual(numel(ginfoOut.nodes), 2);
        end

    end

end
