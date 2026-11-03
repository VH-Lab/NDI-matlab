classdef TestOntologyTableRowDoc2Table < matlab.unittest.TestCase
%TESTONTOLOGYTABLEROWDOC2TABLE ndi.fun.doc.ontologyTableRowDoc2Table on rows
%   with and without a `document_id` dependency.
%
%   Issue #1016: the function called dependency_value_n('document_id') on
%   every row, which errors ("Dependency name document_id not found.") for a
%   row that depends on no document, such as the EPM and FPS rows
%   tableDocMaker writes for the Dabrowska dataset. Such a row now gives an
%   empty dependency entry, and the table is still built.

    methods (Test)

        function testARowWithoutADependencyIsRead(testCase)
            % the reproduction: before the fix this call errored
            doc = tableRow(struct('a', 1, 'b', 2), 'a,b');
            [tables, docIDs, ~, depIDs] = ...
                ndi.fun.doc.ontologyTableRowDoc2Table(doc);
            testCase.verifyNumElements(tables, 1);
            testCase.verifyEqual(height(tables{1}), 1);
            testCase.verifyEqual(docIDs{1}, {doc.id()});
            testCase.verifyNumElements(depIDs{1}, 1);
            testCase.verifyEmpty(depIDs{1}{1});
        end

        function testRowsWithAndWithoutADependencyMix(testCase)
            withDep = tableRow(struct('a', 1, 'b', 2), 'a,b');
            withDep = withDep.set_dependency_value('document_id', 'subject_123');
            without = tableRow(struct('a', 3, 'b', 4), 'a,b');
            [tables, docIDs, ~, depIDs] = ...
                ndi.fun.doc.ontologyTableRowDoc2Table({withDep, without}, ...
                'StackAll', true);
            testCase.verifyEqual(height(tables{1}), 2);
            testCase.verifyEqual(docIDs{1}, {withDep.id(), without.id()});
            testCase.verifyEqual(depIDs{1}{1}, {'subject_123'});
            testCase.verifyEmpty(depIDs{1}{2});
        end

        function testGroupingByVariableNamesStillWorks(testCase)
            d1 = tableRow(struct('a', 1), 'a');
            d2 = tableRow(struct('c', 'x'), 'c');
            [tables, ~, ~, depIDs] = ...
                ndi.fun.doc.ontologyTableRowDoc2Table({d1, d2});
            testCase.verifyNumElements(tables, 2);
            testCase.verifyNumElements(depIDs, 2);
            testCase.verifyEmpty(depIDs{1}{1});
            testCase.verifyEmpty(depIDs{2}{1});
        end
    end
end

function doc = tableRow(data, variableNames)
% an ontologyTableRow document as tableDocMaker writes one with no
% dependency variable: the blank template's `document_id` entry stays empty
row = struct('names', variableNames, 'variableNames', variableNames, ...
    'ontologyNodes', '', 'data', data);
doc = ndi.document('ontologyTableRow', 'ontologyTableRow', row);
end
