classdef TestDaqsystemLoadName < ndi.unittest.session.buildSession
    % TESTDAQSYSTEMLOADNAME - daqsystem_load name searches
    %
    % A 'name' that matches every name ('(.*)', '.*') is dropped from the
    % database search, so it must return the same DAQ systems as no name at
    % all; a specific name must still narrow the result.

    methods (Test)
        function testIsMatchAllRegexp(testCase)
            f = @ndi.session.isMatchAllRegexp;
            for v = {'(.*)', '.*', '^(.*)$', '^.*', '.*$', "(.*)"}
                testCase.verifyTrue(f(v{1}), sprintf('%s should match all', char(v{1})));
            end
            for v = {'intan1', '(.+)', 'a.*', '', 5, {'(.*)'}}
                testCase.verifyFalse(f(v{1}));
            end
        end

        function testMatchAllNameEqualsNoName(testCase)
            S = testCase.Session;
            all1 = testCase.asCell(S.daqsystem_load('name', '(.*)'));
            all2 = testCase.asCell(S.daqsystem_load());
            testCase.verifyNumElements(all1, numel(all2));
            testCase.verifyNotEmpty(all1);
            testCase.verifyEqual(sort(cellfun(@(d) d.id(), all1, 'UniformOutput', false)), ...
                sort(cellfun(@(d) d.id(), all2, 'UniformOutput', false)));
        end

        function testSpecificNameStillFilters(testCase)
            S = testCase.Session;
            d = S.daqsystem_load('name', 'intan1');
            testCase.verifyEqual(d.name, 'intan1');
            testCase.verifyEmpty(S.daqsystem_load('name', 'no_such_daqsystem'));
        end
    end

    methods (Static, Access = private)
        function c = asCell(d)
            if isempty(d)
                c = {};
            elseif iscell(d)
                c = d;
            else
                c = {d};
            end
        end
    end
end
