function probeTypeMap = getProbeTypeMap(options)
    % GETPROBETYPEMAP - Get the map of probe types to object classes
    %
    % PROBETYPEMAP = NDI.PROBE.FUN.GETPROBETYPEMAP()
    %
    % Returns the probe type map, which maps probe type strings to NDI object class names.
    % The map is cached in a persistent variable for performance.
    %
    % PROBETYPEMAP = NDI.PROBE.FUN.GETPROBETYPEMAP('Name', Value, ...)
    %
    % Accepts the following name/value pairs:
    %   'ClearCache' (logical, default false) - If true, the persistent cache is cleared and re-initialized.
    %
    % See also: NDI.PROBE.FUN.INITPROBETYPEMAP

    arguments
        options.ClearCache (1,1) logical = false
    end

    persistent cachedProbeTypeMap

    if options.ClearCache
        cachedProbeTypeMap = [];
    end

    if isempty(cachedProbeTypeMap)
        cachedProbeTypeMap = ndi.probe.fun.initProbeTypeMap();
    end
    probeTypeMap = cachedProbeTypeMap;
end
