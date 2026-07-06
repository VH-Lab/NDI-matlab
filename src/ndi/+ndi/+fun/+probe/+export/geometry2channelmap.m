function [tf, outputfile] = geometry2channelmap(S, probe, outputfile, options)
% NDI.FUN.PROBE.EXPORT.GEOMETRY2CHANNELMAP - build a KIASORT/Kilosort channel map from an NDI probe_geometry
%
% [TF, OUTPUTFILE] = NDI.FUN.PROBE.EXPORT.GEOMETRY2CHANNELMAP(S, PROBE, OUTPUTFILE, ...)
%
% Reads the 'probe_geometry' (and 'site2channelmap') documents that describe the
% electrode geometry of PROBE in the ndi.session S, and writes a Kilosort-style
% channel-map .mat file OUTPUTFILE (via NDI.FUN.PROBE.EXPORT.CHANNELMAP) whose
% xcoords/ycoords/kcoords/connected are aligned to the channel order of the binary
% exported by NDI.FUN.PROBE.EXPORT.BINARY. KIASORT's load_channel_map accepts this
% file directly, so a sort then uses the probe's real spatial layout.
%
% Returns TF = true and writes OUTPUTFILE if a probe_geometry document was found;
% TF = false and writes nothing if the probe has no geometry on file (so callers,
% e.g. ndi.fun.probe.import.kiasort.run, can fall back to a default map).
%
% ALIGNMENT: NDI stores per-site coordinates in 'probe_geometry'
% (site_locations_leftright, site_locations_frontback, site_locations_depth,
% shank_id) and a 'site2channelmap' whose 'map' column gives, for each site i, the
% recording channel index map(i). The exported binary orders channels 1..N in the
% probe's channel order, so this function inverts the map: for each site i it places
% that site's coordinates at channel map(i). Channels with no site are marked
% connected=false. If no 'site2channelmap' is found, an identity map (site i ->
% channel i) is assumed (with a warning) when the site count matches num_channels.
%
% By convention the Kilosort horizontal axis (xcoords) is the probe's left/right
% axis and the vertical axis (ycoords) is depth (matching ndi.fun.probe.plotProbeGeometry).
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | num_channels ([])        | Number of channels in the export. If empty, read a  |
% |                          |   single sample from the probe to determine it.     |
% | horizontal_axis          | Which probe axis maps to xcoords: 'leftright' or    |
% |   ('leftright')          |   'frontback'. ycoords is always depth.             |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.EXPORT.CHANNELMAP, NDI.FUN.PROBE.IMPORT.KIASORT.RUN,
%   NDI.FUN.PROBE.PLOTPROBEGEOMETRY

    arguments
        S
        probe
        outputfile (1,:) char
        options.num_channels double = []
        options.horizontal_axis (1,:) char {mustBeMember(options.horizontal_axis,{'leftright','frontback'})} = 'leftright'
        options.verbose (1,1) double = 1
    end

    tf = false;

    % Step 1: find the probe_geometry document for this probe
    q_geom = ndi.query('','isa','probe_geometry','') & ...
        ndi.query('','depends_on','probe_id',probe.id());
    geomdocs = S.database_search(q_geom);

    if isempty(geomdocs),
        if options.verbose,
            disp(['No probe_geometry document found for probe ' probe.elementstring() '.']);
        end;
        return;
    end;
    if numel(geomdocs)>1 && options.verbose,
        warning('ndi:fun:probe:export:geometry2channelmap:multipleGeometry', ...
            ['Found %d probe_geometry documents for probe %s; using the first.'], ...
            numel(geomdocs), probe.elementstring());
    end;
    geomdoc = geomdocs{1};
    pg = geomdoc.document_properties.probe_geometry;

    % Step 2: number of channels in the exported binary
    num_channels = options.num_channels;
    if isempty(num_channels),
        et = probe.epochtable();
        if isempty(et),
            error(['Probe ' probe.elementstring() ' has no epochs; cannot determine num_channels.']);
        end;
        t0 = et(1).t0_t1{1}(1);
        [d,~] = probe.readtimeseries(et(1).epoch_id, t0, t0);
        num_channels = size(d,2);
    end;
    num_channels = double(num_channels);

    % Step 3: per-site coordinates
    depth = double(pg.site_locations_depth(:));
    if strcmp(options.horizontal_axis,'frontback') && isfield(pg,'site_locations_frontback') ...
            && ~isempty(pg.site_locations_frontback),
        horiz = double(pg.site_locations_frontback(:));
    else,
        horiz = double(pg.site_locations_leftright(:));
    end;
    if isfield(pg,'shank_id') && ~isempty(pg.shank_id),
        shank = double(pg.shank_id(:));
    else,
        shank = [];
    end;

    nSites = min([numel(depth) numel(horiz)]);
    if nSites==0,
        if options.verbose,
            disp(['probe_geometry for probe ' probe.elementstring() ' has no site locations.']);
        end;
        return;
    end;

    % Step 4: site -> channel map (map(i) is the channel index for site i)
    q_s2c = ndi.query('','isa','site2channelmap','') & ...
        ndi.query('','depends_on','probe_geometry_id',geomdoc.id());
    s2cdocs = S.database_search(q_s2c);

    if ~isempty(s2cdocs),
        map = double(s2cdocs{1}.document_properties.site2channelmap.map(:));
    else,
        % no explicit map: assume site i -> channel i, but only if the counts agree
        if nSites~=num_channels,
            if options.verbose,
                warning('ndi:fun:probe:export:geometry2channelmap:noMap', ...
                    ['No site2channelmap for probe %s and site count (%d) ~= num_channels (%d); ' ...
                    'cannot align geometry to channels. Falling back to no geometry.'], ...
                    probe.elementstring(), nSites, num_channels);
            end;
            return;
        end;
        if options.verbose,
            warning('ndi:fun:probe:export:geometry2channelmap:identityMap', ...
                ['No site2channelmap for probe %s; assuming site i -> channel i.'], probe.elementstring());
        end;
        map = (1:nSites)';
    end;

    % tolerate a 0-based channel map (convert to 1-based) if it looks 0-based
    map_valid = map(~isnan(map));
    if ~isempty(map_valid) && min(map_valid)==0 && max(map_valid)<=num_channels-1,
        map = map + 1;
    end;

    % Step 5: place each site's coordinates at its channel; unmapped channels are
    % left at the origin and marked not-connected.
    xcoords = zeros(num_channels,1);
    ycoords = zeros(num_channels,1);
    kcoords = ones(num_channels,1);
    connected = false(num_channels,1);

    nUse = min(nSites, numel(map));
    for i=1:nUse,
        ch = map(i);
        if isnan(ch) || ch<1 || ch>num_channels,
            continue; % site not recorded on any exported channel
        end;
        ch = round(ch);
        xcoords(ch) = horiz(i);
        ycoords(ch) = depth(i);
        if ~isempty(shank) && i<=numel(shank),
            kcoords(ch) = shank(i);
        end;
        connected(ch) = true;
    end;

    if ~any(connected),
        if options.verbose,
            warning('ndi:fun:probe:export:geometry2channelmap:noAlignment', ...
                ['The site2channelmap for probe %s did not place any site on channels 1..%d; ' ...
                'falling back to no geometry.'], probe.elementstring(), num_channels);
        end;
        return;
    end;

    % Step 6: write the Kilosort-style map (real geometry -> no default-geometry warning)
    ndi.fun.probe.export.channelmap(outputfile, 'num_channels', num_channels, ...
        'chanMap', (1:num_channels)', 'connected', connected, ...
        'xcoords', xcoords, 'ycoords', ycoords, 'kcoords', kcoords, ...
        'verbose', options.verbose);

    if options.verbose,
        disp(['Built channel map from probe_geometry for probe ' probe.elementstring() ' (' ...
            int2str(sum(connected)) ' of ' int2str(num_channels) ' channels have sites).']);
    end;

    tf = true;

end
