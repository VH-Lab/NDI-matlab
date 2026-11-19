classdef TestEarliestByContent < matlab.unittest.TestCase
%TESTEARLIESTBYCONTENT ndi.migrate.internal.earliestByContent: a value the
%   second pass chooses among several contributing documents is chosen by
%   content (earliest timestamp, ties by id), never by read order
%   (NDI-matlab #1235: database order is not data).
%
%   Run with:  runtests('ndi.unittest.migrate.TestEarliestByContent')

    methods (Test)

        function testTheEarliestInstantWinsInEitherOrder(testCase)
            late = '2024-06-03T10:00:00.000Z';
            early = '2024-05-31T08:00:00.000Z';
            f = @ndi.migrate.internal.earliestByContent;
            testCase.verifyEqual(f({late, early}, {'a', 'b'}), 2);
            testCase.verifyEqual(f({early, late}, {'b', 'a'}), 1);
        end

        function testEqualInstantsAreBrokenByTheSmallerId(testCase)
            t = '2024-06-01T12:00:00.000Z';
            f = @ndi.migrate.internal.earliestByContent;
            testCase.verifyEqual(f({t, t}, {'z', 'a'}), 2);
            testCase.verifyEqual(f({t, t}, {'a', 'z'}), 1);
        end

        function testAnOffsetIsReadAsTheInstantItNames(testCase)
            % 13:00+02:00 is 11:00Z, before 12:00Z
            f = @ndi.migrate.internal.earliestByContent;
            testCase.verifyEqual(f({'2024-06-01T12:00:00.000Z', ...
                '2024-06-01T13:00:00+02:00'}, {'a', 'b'}), 2);
        end

        function testAParsedStampRanksBeforeAnUnparsedOrEmptyOne(testCase)
            f = @ndi.migrate.internal.earliestByContent;
            testCase.verifyEqual(f({'', 'not a time', '2030-01-01T00:00:00Z'}, ...
                {'a', 'b', 'c'}), 3);
            testCase.verifyEqual(f({'', 'zz', 'yy'}, {'a', 'b', 'c'}), 3, ...
                'unparsed stamps rank in character order, before an empty one');
            testCase.verifyEqual(f({'', ''}, {'q', 'p'}), 2, ...
                'no stamp at all: the smaller id');
        end

        function testNoContributorsGiveNoChoice(testCase)
            testCase.verifyEmpty(ndi.migrate.internal.earliestByContent({}, {}));
        end

    end
end
