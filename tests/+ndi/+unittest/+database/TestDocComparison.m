classdef TestDocComparison < matlab.unittest.TestCase
    methods (Test)
        function testConstruction(testCase)
            d = ndi.document(struct('base', struct('id', '1', 'name', 'test'), 'A', 5, 'B', struct('C', 10), 'arr', [1 2]));
            dc = ndi.database.doctools.docComparison(d);

            s = dc.comparisonStruct;
            testCase.verifyNotEmpty(s);

            names = {s.name};
            testCase.verifyTrue(any(strcmp(names, 'base.id')));
            testCase.verifyTrue(any(strcmp(names, 'base.name')));
            testCase.verifyTrue(any(strcmp(names, 'A')));
            testCase.verifyTrue(any(strcmp(names, 'B.C')));
            testCase.verifyTrue(any(strcmp(names, 'arr')));

            % Verify defaults
            testCase.verifyTrue(all(strcmp({s.comparisonMethod}, 'none')));
            testCase.verifyTrue(all([s.toleranceAmount] == 0));
        end

        function testArrayStructConstruction(testCase)
            d = ndi.document(struct('base', struct('id','1','name','test'), 'S', struct('val', {1, 2})));
            dc = ndi.database.doctools.docComparison(d);

            s = dc.comparisonStruct;
            names = {s.name};

            % If S is a struct array, we expect S(1).val and S(2).val
            testCase.verifyTrue(any(strcmp(names, 'S(1).val')));
            testCase.verifyTrue(any(strcmp(names, 'S(2).val')));
        end

        function testComparisonLogic(testCase)
             d1 = ndi.document(struct('base', struct('id', '1'), 'val', 10));
             d2 = ndi.document(struct('base', struct('id', '1'), 'val', 12));

             dc = ndi.database.doctools.docComparison(d1);

             % Default: none
             [b, report] = dc.compare(d1, d2);
             testCase.verifyTrue(b);
             testCase.verifyEmpty(report);

             % Add comparison
             dc = dc.addComparisonParameters('val', 'abs difference', 1);
             [b, report] = dc.compare(d1, d2);
             testCase.verifyFalse(b);
             testCase.verifyEqual(numel(report), 1);
             testCase.verifyEqual(report(1).name, 'val');

             % Increase tolerance
             dc = dc.addComparisonParameters('val', 'abs difference', 3);
             [b, report] = dc.compare(d1, d2);
             testCase.verifyTrue(b);

             % Percent difference
             % 10 vs 12. diff=2. 2/12 = 0.166... = 16.6%
             dc = dc.addComparisonParameters('val', 'abs percent difference', 10);
             [b, report] = dc.compare(d1, d2);
             testCase.verifyFalse(b); % 16.6 > 10

             dc = dc.addComparisonParameters('val', 'abs percent difference', 20);
             [b, report] = dc.compare(d1, d2);
             testCase.verifyTrue(b);
        end

        function testMissingField(testCase)
             d1 = ndi.document(struct('base', struct('id', '1'), 'val', 10));
             d2 = ndi.document(struct('base', struct('id', '1'))); % missing val

             dc = ndi.database.doctools.docComparison(d1);
             dc = dc.addComparisonParameters('val', 'abs difference', 1);

             [b, report] = dc.compare(d1, d2);
             testCase.verifyFalse(b);
             testCase.verifyEqual(report(1).comment, 'Field missing or error accessing');
        end

        function testNumericRequirement(testCase)
            d1 = ndi.document(struct('base', struct('id', '1'), 'str', 'hello'));
            d2 = ndi.document(struct('base', struct('id', '1'), 'str', 'world'));

            dc = ndi.database.doctools.docComparison(d1);
            dc = dc.addComparisonParameters('str', 'abs difference', 0);

            [b, report] = dc.compare(d1, d2);
            testCase.verifyFalse(b);
            testCase.verifyEqual(report(1).comment, 'Values are not numeric, cannot apply comparison method.');
        end

        function testCharacterExact(testCase)
            d1 = ndi.document(struct('base', struct('id', '1'), 'str', 'hello'));
            d2 = ndi.document(struct('base', struct('id', '1'), 'str', 'world'));
            d3 = ndi.document(struct('base', struct('id', '1'), 'str', 'hello'));

            dc = ndi.database.doctools.docComparison(d1);
            dc = dc.addComparisonParameters('str', 'character exact', 0);

            % Match
            [b, report] = dc.compare(d1, d3);
            testCase.verifyTrue(b);

            % Mismatch
            [b, report] = dc.compare(d1, d2);
            testCase.verifyFalse(b);
            testCase.verifyEqual(report(1).comment, 'Strings do not match exactly.');

            % Numeric input failure
            d4 = ndi.document(struct('base', struct('id', '1'), 'str', 123));
            [b, report] = dc.compare(d1, d4);
            testCase.verifyFalse(b);
            testCase.verifyEqual(report(1).comment, 'Values are not characters/strings, cannot apply character exact comparison.');
        end

        function testJsonSerialization(testCase)
            d = ndi.document(struct('base', struct('id', '1', 'name', 'test'), 'A', 5));
            dc = ndi.database.doctools.docComparison(d);
            dc = dc.addComparisonParameters('A', 'abs difference', 0.1);

            jsonStr = dc.toJson();
            testCase.verifyTrue(ischar(jsonStr));

            % Reconstruct from JSON
            dc2 = ndi.database.doctools.docComparison(jsonStr);
            s2 = dc2.comparisonStruct;

            testCase.verifyEqual(numel(s2), numel(dc.comparisonStruct));

            % Find 'A' in new struct
            idx = find(strcmp({s2.name}, 'A'));
            testCase.verifyNotEmpty(idx);
            testCase.verifyEqual(s2(idx).comparisonMethod, 'abs difference');
            testCase.verifyEqual(s2(idx).toleranceAmount, 0.1);
        end

        function testDimensionMismatch(testCase)
            d1 = ndi.document(struct('base', struct('id', '1'), 'val', [1 2]));
            d2 = ndi.document(struct('base', struct('id', '1'), 'val', [1 2 3]));

            dc = ndi.database.doctools.docComparison(d1);
            dc = dc.addComparisonParameters('val', 'abs difference', 0);

            [b, report] = dc.compare(d1, d2);
            testCase.verifyFalse(b);
            testCase.verifyEqual(report(1).comment, 'Dimension mismatch between actual and expected values.');
        end
    end
end
