classdef organizationLabelsTest < matlab.unittest.TestCase
% organizationLabelsTest - Offline tests for the organization label builder.
%
%   Exercises ndi.cloud.ui.dialog.organizationLabels, the pure helper that
%   turns parallel organization name/id lists (as returned by
%   ndi.cloud.api.users.me) into unique, name-first display labels for the
%   organization picker. Requires no network access or credentials.

    methods (Test)
        function testNamesUsedWhenUnique(testCase)
            labels = ndi.cloud.ui.dialog.organizationLabels( ...
                {'Alpha Lab', 'Beta Institute'}, {'org-1', 'org-2'});
            testCase.verifyEqual(labels, {'Alpha Lab', 'Beta Institute'});
            testCase.verifyClass(labels{1}, 'char');
        end

        function testEmptyNameFallsBackToId(testCase)
            labels = ndi.cloud.ui.dialog.organizationLabels( ...
                {'', 'Beta'}, {'org-1', 'org-2'});
            testCase.verifyEqual(labels{1}, 'org-1');
            testCase.verifyEqual(labels{2}, 'Beta');
        end

        function testDuplicateNamesGetIdAppended(testCase)
            % When two organizations share a name, the id is appended to both
            % so the labels stay unique keys for the list dialog.
            labels = ndi.cloud.ui.dialog.organizationLabels( ...
                {'Shared', 'Shared'}, {'org-1', 'org-2'});
            testCase.verifyEqual(labels{1}, 'Shared  (org-1)');
            testCase.verifyEqual(labels{2}, 'Shared  (org-2)');
            testCase.verifyNotEqual(labels{1}, labels{2});
        end

        function testStringInputsCoercedToChar(testCase)
            % jsondecode can produce string-typed values; labels must be char.
            labels = ndi.cloud.ui.dialog.organizationLabels( ...
                {"Gamma Center"}, {"org-9"});
            testCase.verifyEqual(labels{1}, 'Gamma Center');
            testCase.verifyClass(labels{1}, 'char');
        end

        function testFewerNamesThanIdsTreatedAsEmpty(testCase)
            % A names list shorter than the ids list must not error; the
            % missing name falls back to the id.
            labels = ndi.cloud.ui.dialog.organizationLabels( ...
                {'Alpha'}, {'org-1', 'org-2'});
            testCase.verifyEqual(labels{1}, 'Alpha');
            testCase.verifyEqual(labels{2}, 'org-2');
        end

        function testEmptyListGivesEmptyLabels(testCase)
            labels = ndi.cloud.ui.dialog.organizationLabels({}, {});
            testCase.verifyEmpty(labels);
        end
    end
end
