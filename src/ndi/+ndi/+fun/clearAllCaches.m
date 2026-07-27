function clearAllCaches(varargin)
% CLEARALLCACHES - clear all NDI/DID in-memory caches
%
% ndi.fun.CLEARALLCACHES(OBJ1, OBJ2, ...)
%
% Clears the in-memory caches that NDI builds up during a long-lived MATLAB
% session. This is a convenience for when definitions, schemas, or path
% contents have changed on disk (or during development/tests) but a running
% session is still using stale cached copies. It spans more than the database
% layer, which is why it lives in ndi.fun rather than ndi.database.fun.
%
% The following caches are cleared:
%   1. The global ndi.cache singleton (ndi.common.getCache) - holds things
%      like cached epoch tables. Clearing it also runs clearAllMemoizedCaches
%      and 'clear memoize', so memoized functions (such as the file-navigator
%      findfilegroups memo) are reset as well.
%   2. The probe-type map (persistent inside ndi.probe.fun.getProbeTypeMap).
%   3. The calculator subclass list (persistent inside
%      ndi.calculator.find_calculator_subclasses).
%   4. The NDI document-definition memo and the DID file-cache singleton, plus
%      the ndi.cache of any ndi.session / ndi.cache passed as an argument (all
%      via ndi.database.fun.clearcaches).
%   5. The database hierarchy (persistent inside
%      ndi.common.getDatabaseHierarchy).
%
% Configuration singletons that hold user state or static lookups are left
% untouched (e.g. ndi.preferences, ndi.common.getLogger,
% ndi.common.PathConstants, ndi.cloud.profile, and the ndi.cloud.api.url
% endpoint map).
%
% With no arguments, the global caches above are cleared. To also clear a
% particular dataset's cache, pass its linked ndi.session object(s).
%
% A full MATLAB restart (or 'clear classes') clears every persistent as well,
% and is the surest reset if anything still looks stale.
%
% Example:
%   ndi.fun.clearAllCaches();     % clear all global NDI caches
%   ndi.fun.clearAllCaches(S);    % also clear session S's cache
%
% See also: ndi.database.fun.clearcaches, ndi.cache, ndi.common.getCache

    % 1) document-definition memo, DID file-cache, and any passed session caches
    try
        ndi.database.fun.clearcaches(varargin{:});
    catch
        % ignore: nothing to clear or not clearable in this context
    end

    % 2) the global ndi.cache singleton (also clears memoized caches)
    try
        c = ndi.common.getCache();
        if ~isempty(c) && isa(c, 'ndi.cache')
            c.clear();
        end
    catch
        % ignore: nothing to clear or not clearable in this context
    end

    % 3) the probe-type map
    try
        ndi.probe.fun.getProbeTypeMap('ClearCache', true);
    catch
        % ignore: nothing to clear or not clearable in this context
    end

    % 4) the calculator subclass list
    try
        ndi.calculator.find_calculator_subclasses('ClearCache', true);
    catch
        % ignore: nothing to clear or not clearable in this context
    end

    % 5) the database hierarchy (persistent inside getDatabaseHierarchy)
    try
        clear('ndi.common.getDatabaseHierarchy');
    catch
        % ignore: nothing to clear or not clearable in this context
    end

end % clearAllCaches()
