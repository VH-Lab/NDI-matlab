classdef FakeProcess < handle
% FAKEPROCESS - stands in for a java.lang.Process in tests (isAlive, destroy)
%
%   See also: ndi.test.helper.FakeLauncher

    properties (SetAccess = private)
        args = {}
        alive (1,1) logical = true
    end

    methods
        function obj = FakeProcess(args)
            obj.args = args;
        end

        function tf = isAlive(obj)
            tf = obj.alive;
        end

        function destroy(obj)
            obj.alive = false;
        end

        function exitNow(obj)
        % As a helper that stopped by itself (refused, or missing).
            obj.alive = false;
        end
    end
end
