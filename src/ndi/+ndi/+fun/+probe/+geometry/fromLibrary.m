function [pg_doc, s2c_doc, info] = fromLibrary(S, probe, name, options)
% NDI.FUN.PROBE.GEOMETRY.FROMLIBRARY - attach a library electrode layout to a probe
%
% [PG_DOC, S2C_DOC] = NDI.FUN.PROBE.GEOMETRY.FROMLIBRARY(S, PROBE, NAME, ...)
%
% Looks up the electrode layout NAME in the NDI library (see
% NDI.FUN.PROBE.GEOMETRY.LISTLIBRARY / READLIBRARY) and creates a 'probe_geometry'
% document for PROBE in the ndi.session S from it.
%
% A library layout describes the physical electrode sites. Some fixed-headstage
% layouts also ship a default site->channel wiring in their 'map' field; when
% present (and no 'map' option is supplied) that default is used to additionally
% create a 'site2channelmap' document. You can always override it (or supply a
% wiring for a geometry-only layout) via the 'map' option (map(i) = recording
% channel of site i; NaN if a site is not recorded). With neither a supplied nor a
% shipped map, only probe_geometry is created.
%
% NAME may be 'group/model' or a bare 'model' (searched across groups).
%
% Name/value pairs:
%   map ([])       - site->channel column; overrides any map shipped with the
%                     layout. When non-empty, also create site2channelmap.
%   add (true)     - add the created documents to S's database.
%   replace (false)- before adding, remove any existing probe_geometry for this probe
%                     (so re-assigning replaces rather than stacks a second geometry).
%   verbose (1)    - 0/1 report what was created.
%
% Example:
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.geometry.fromLibrary(S, p{1}, 'neuropixels/NP2_1shank');
%
% See also: NDI.FUN.PROBE.GEOMETRY.READLIBRARY, NDI.FUN.PROBE.GEOMETRY.LISTLIBRARY,
%   NDI.FUN.PROBE.GEOMETRY.FROMSTRUCT, NDI.FUN.PROBE.GEOMETRY.FROMKILOSORTMAP

    arguments
        S
        probe
        name (1,:) char
        options.map double = []
        options.add (1,1) logical = true
        options.replace (1,1) logical = false
        options.verbose (1,1) double = 1
    end

    geom = ndi.fun.probe.geometry.readLibrary(name);

    % A layout may ship a default site->channel wiring in its 'map' field. A
    % caller-supplied 'map' takes precedence; otherwise the shipped default (if any)
    % is used. 'map' is not a probe_geometry field, so it is removed from GEOM before
    % the geometry document is built.
    map = options.map;
    if isfield(geom,'map'),
        if isempty(map) && ~isempty(geom.map),
            map = geom.map(:);
        end;
        geom = rmfield(geom,'map');
    end;

    [pg_doc, s2c_doc, info] = ndi.fun.probe.geometry.fromStruct(S, probe, geom, ...
        'map', map, 'add', options.add, 'replace', options.replace, ...
        'verbose', options.verbose);

end
