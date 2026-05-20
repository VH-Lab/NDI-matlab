classdef runStateRef < handle
%RUNSTATEREF Small handle-class holding ndi.migrate.cloud's mutable flags.
%
%   `onCleanup` callbacks need a way to learn whether the success
%   path already released the lock / re-published the dataset, so
%   they no-op instead of double-actioning on the success path or
%   re-actioning if the cleanup fires from inside the function's own
%   normal exit. A handle class with two booleans is the smallest
%   thing that lets the cleanup callbacks share state with the
%   function body without passing structs by reference.
%
%   See also: ndi.migrate.cloud.

    properties
        lockReleased (1,1) logical = false
        republished  (1,1) logical = false
    end

    methods
        function set(obj, name, value)
            obj.(name) = value;
        end

        function v = get(obj, name)
            v = obj.(name);
        end
    end
end
