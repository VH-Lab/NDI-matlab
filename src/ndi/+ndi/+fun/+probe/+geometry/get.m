function G = get(S, probe, options)
% NDI.FUN.PROBE.GEOMETRY.GET - fetch the geometry documents for a probe
%
% G = NDI.FUN.PROBE.GEOMETRY.GET(S, PROBE, ...)
%
% Looks up the 'probe_geometry' (and 'site2channelmap') documents that describe the
% electrode geometry of PROBE in the ndi.session S and returns them in a struct G:
%
%   G.found    - true if a probe_geometry document was found
%   G.pg       - the probe_geometry property struct (site_locations_*, shank_id, ...)
%                  or [] if none
%   G.pg_doc   - the probe_geometry ndi.document, or []
%   G.map      - the site->channel map column from site2channelmap (map(i) is the
%                  recording channel for site i), or [] if there is no site2channelmap
%   G.s2c_doc  - the site2channelmap ndi.document, or []
%
% Name/value pairs:
%   verbose (0) - 0/1 warn when multiple probe_geometry documents are found.
%
% See also: NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP, NDI.FUN.PROBE.GEOMETRY.FROMKILOSORTMAP,
%   NDI.FUN.PROBE.PLOTPROBEGEOMETRY

    arguments
        S
        probe
        options.verbose (1,1) double = 0
    end

    G = struct('found',false,'pg',[],'pg_doc',[],'map',[],'s2c_doc',[]);

    q_geom = ndi.query('','isa','probe_geometry','') & ...
        ndi.query('','depends_on','probe_id',probe.id());
    geomdocs = S.database_search(q_geom);

    if isempty(geomdocs),
        return;
    end;
    if numel(geomdocs)>1 && options.verbose,
        warning('ndi:fun:probe:geometry:get:multipleGeometry', ...
            'Found %d probe_geometry documents for probe %s; using the first.', ...
            numel(geomdocs), probe.elementstring());
    end;

    G.pg_doc = geomdocs{1};
    G.pg = G.pg_doc.document_properties.probe_geometry;
    G.found = true;

    q_s2c = ndi.query('','isa','site2channelmap','') & ...
        ndi.query('','depends_on','probe_geometry_id',G.pg_doc.id());
    s2cdocs = S.database_search(q_s2c);
    if ~isempty(s2cdocs),
        G.s2c_doc = s2cdocs{1};
        G.map = double(G.s2c_doc.document_properties.site2channelmap.map(:));
    end;

end
