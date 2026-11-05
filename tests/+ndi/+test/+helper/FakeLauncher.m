classdef FakeLauncher < handle
% FAKELAUNCHER - stands in for ndi.util.startProcess in ndi.util.KeepAwake
%
%   L = ndi.test.helper.FakeLauncher.install(testCase)
%
%   Points ndi.util.KeepAwake.instance() at L for the rest of the test, so
%   nothing really keeps the computer awake; L.processes lists what would
%   have been started (ndi.test.helper.FakeProcess). At teardown every
%   hold is released and the real launcher is put back.

    properties (SetAccess = private)
        processes = {}
    end

    methods (Static)
        function L = install(testCase)
            L = ndi.test.helper.FakeLauncher();
            k = ndi.util.KeepAwake.instance();
            previous = k.Launcher;
            k.Launcher = @(args) L.start(args);
            testCase.addTeardown(@() ndi.test.helper.FakeLauncher.restore(k, previous));
        end
    end

    methods
        function p = start(obj, args)
            p = ndi.test.helper.FakeProcess(args);
            obj.processes{end+1} = p;
        end

        function n = running(obj)
        % RUNNING - how many of the started processes are still alive
            n = sum(cellfun(@(p) p.isAlive(), obj.processes));
        end
    end

    methods (Static, Access = private)
        function restore(k, previous)
            held = k.keys;
            for i = 1:numel(held)
                k.release(held{i});
            end
            k.Launcher = previous;
        end
    end
end
