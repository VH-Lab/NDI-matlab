classdef TestDimensionTermCensus < matlab.unittest.TestCase
%TESTDIMENSIONTERMCENSUS ndi.migrate.internal.dimensionTermCensus counts the
%   dimensions written whose term has no node, against the dimensions written
%   (Decided by Jess Haley, 2026-10-22 [covariate details], 5.4 "B").

    methods (Test)
        function testDenominatorsComeFirstAndCountsAreExact(testCase)
            docs = { ...
                withDims('manipulation', {struct('term', struct('node', 'OBI:0000807', ...
                    'name', 'presentation of stimulus'), 'n', 3)}), ...
                withDims('calculation', {struct('term', struct('node', '', 'name', 'row'), 'n', 2), ...
                    struct('term', struct('node', 'NCIT:C62143', 'name', 'Encounter'), 'n', 2)}), ...
                withDims('calculation', {struct('term', struct('name', 'row'), 'n', 4)}), ...
                struct('document_class', struct('class_name', 'subject'), 'base', struct('id', 'x'))};
            r = ndi.migrate.internal.dimensionTermCensus(docs);
            f = fieldnames(r);
            testCase.verifyEqual(f{1}, 'documents_inspected');
            testCase.verifyEqual(r.documents_inspected, 4);
            testCase.verifyEqual(r.documents_with_dimensions, 3);
            testCase.verifyEqual(r.dimensions_written, 4);
            testCase.verifyEqual(r.dimensions_without_node, 2);
            testCase.verifyEqual(numel(r.without_node_by_term), 1);
            testCase.verifyEqual(r.without_node_by_term(1).name, 'row');
            testCase.verifyEqual(r.without_node_by_term(1).class_name, 'calculation');
            testCase.verifyEqual(r.without_node_by_term(1).count, 2);
        end

        function testNoDocumentsIsMeasuredAsZeroOfZero(testCase)
            r = ndi.migrate.internal.dimensionTermCensus({});
            testCase.verifyEqual(r.documents_inspected, 0);
            testCase.verifyEqual(r.dimensions_written, 0);
            testCase.verifyEqual(r.dimensions_without_node, 0);
        end
    end
end

function d = withDims(cls, dims)
d = struct('document_class', struct('class_name', cls), 'base', struct('id', cls), ...
    'data', struct('dimensions', {dims}));
end
