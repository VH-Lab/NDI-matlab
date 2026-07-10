function [pg_doc, s2c_doc] = fromKilosortMap(S, probe, source, options)
% NDI.FUN.PROBE.GEOMETRY.FROMKILOSORTMAP - create NDI geometry documents from a Kilosort-style channel map
%
% [PG_DOC, S2C_DOC] = NDI.FUN.PROBE.GEOMETRY.FROMKILOSORTMAP(S, PROBE, SOURCE, ...)
%
% Reads a Kilosort/KIASORT-style channel map and creates the NDI documents that
% describe the electrode geometry of PROBE in the ndi.session S:
%
%   pg_doc  - a 'probe_geometry' document (per-site coordinates), and
%   s2c_doc - a 'site2channelmap' document (which recording channel each site is).
%
% This is the inverse of NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP: after running it,
% that function (and ndi.fun.probe.import.kiasort.run) will build a channel map for
% KIASORT from the probe's stored geometry instead of a linear placeholder.
%
% SOURCE is either:
%   - a path to a .mat file containing the channel-map variables, or
%   - a struct with those variables as fields.
% The recognized fields (Kilosort convention) are:
%   xcoords    (required) - N x 1 horizontal position (microns) of each channel
%   ycoords    (required) - N x 1 vertical/depth position (microns) of each channel
%   kcoords    (optional) - N x 1 shank id per channel (default all ones)
%   connected  (optional) - N x 1 logical, which channels are live (default all true)
%   chanMap    (optional) - N x 1 channel indices; validated for length only (the
%                            coordinates are taken as already in recording-channel
%                            order, which is how Kilosort stores xcoords/ycoords)
%   name       (optional) - probe model string (e.g. 'NP2')
%
% Coordinate/axis mapping into probe_geometry:
%   xcoords -> site_locations_leftright
%   ycoords -> site_locations_depth
%   kcoords -> shank_id
%   site_locations_frontback is set to zeros (a planar/2-D probe).
%
% site2channelmap.map is built as site i -> channel i for connected channels and
% NaN for unconnected channels, so a subsequent NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP
% reproduces the same connected mask.
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default) | Description                                              |
% |---------------------|----------------------------------------------------------|
% | probe_model ('')    | Overrides the model string (else uses SOURCE.name).      |
% | manufacturer ('')   | Manufacturer string for the probe_geometry document.     |
% | unit ('um')         | Spatial unit stored in the probe_geometry document.      |
% | add (true)          | Add the created documents to S's database. If false, the |
% |                     |   documents are returned but not committed.              |
% | verbose (1)         | 0/1 Should we be verbose?                               |
% ---------------------------------------------------------------------------------
%
% Example (an NP2 channel map):
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.geometry.fromKilosortMap(S, p{1}, '/path/to/NP2_channel_map.mat');
%    % verify:
%    G = ndi.fun.probe.geometry.get(S, p{1});
%    ndi.fun.probe.plotProbeGeometry(G.pg_doc);
%
% See also: NDI.FUN.PROBE.GEOMETRY.TOKILOSORTMAP, NDI.FUN.PROBE.GEOMETRY.GET,
%   NDI.FUN.PROBE.PLOTPROBEGEOMETRY

    arguments
        S
        probe
        source
        options.probe_model (1,:) char = ''
        options.manufacturer (1,:) char = ''
        options.unit (1,:) char = 'um'
        options.add (1,1) logical = true
        options.verbose (1,1) double = 1
    end

    % Step 1: obtain the channel-map variables as a struct
    if ischar(source) || isstring(source),
        source = char(source);
        if ~isfile(source),
            error(['Channel map file not found: ' source '.']);
        end;
        m = load(source);
    elseif isstruct(source),
        m = source;
    else,
        error('SOURCE must be a .mat file path or a struct of channel-map variables.');
    end;

    if ~isfield(m,'xcoords') || ~isfield(m,'ycoords'),
        error('The channel map must contain at least ''xcoords'' and ''ycoords''.');
    end;

    xcoords = double(m.xcoords(:));
    ycoords = double(m.ycoords(:));
    n = numel(xcoords);
    if numel(ycoords)~=n,
        error('xcoords and ycoords must have the same number of elements.');
    end;

    if isfield(m,'kcoords') && ~isempty(m.kcoords),
        kcoords = double(m.kcoords(:));
    else,
        kcoords = ones(n,1);
    end;

    if isfield(m,'connected') && ~isempty(m.connected),
        connected = logical(m.connected(:));
    else,
        connected = true(n,1);
    end;

    if numel(kcoords)~=n,
        error('kcoords must have the same number of elements as xcoords (%d).', n);
    end;
    if numel(connected)~=n,
        error('connected must have the same number of elements as xcoords (%d).', n);
    end;

    if isfield(m,'chanMap') && ~isempty(m.chanMap) && numel(m.chanMap)~=n,
        error('chanMap, if present, must have the same number of elements as xcoords (%d).', n);
    end;

    probe_model = options.probe_model;
    if isempty(probe_model) && isfield(m,'name') && ~isempty(m.name),
        probe_model = char(m.name);
    end;

    % Step 2: build and create the probe_geometry document
    pg = struct();
    pg.site_locations_leftright = xcoords;
    pg.site_locations_frontback = zeros(n,1);
    pg.site_locations_depth = ycoords;
    pg.shank_id = kcoords;
    pg.contact_shape = '';
    pg.contact_shape_width = [];
    pg.contact_shape_height = [];
    pg.contact_shape_radius = [];
    pg.probe_model = probe_model;
    pg.manufacturer = options.manufacturer;
    pg.ndim = 2;
    pg.unit = options.unit;
    pg.has_planar_contour = 0;
    pg.contour_x = [];
    pg.contour_y = [];

    pg_doc = ndi.document('probe_geometry','probe_geometry',pg,'base.session_id',S.id());
    pg_doc = pg_doc.set_dependency_value('probe_id', probe.id());

    % Step 3: build the site->channel map (site i -> channel i; NaN if not connected)
    map = (1:n)';
    map(~connected) = NaN;

    s2c = struct('map', map);
    s2c_doc = ndi.document('site2channelmap','site2channelmap',s2c,'base.session_id',S.id());
    s2c_doc = s2c_doc.set_dependency_value('probe_id', probe.id());
    s2c_doc = s2c_doc.set_dependency_value('probe_geometry_id', pg_doc.id());

    % Step 4: commit
    if options.add,
        S.database_add(pg_doc);
        S.database_add(s2c_doc);
    end;

    if options.verbose,
        modelstr = probe_model; if isempty(modelstr), modelstr = '(unnamed)'; end;
        action = 'Created'; if options.add, action = 'Added'; end;
        disp([action ' probe_geometry (' modelstr ', ' int2str(n) ' sites, ' ...
            int2str(sum(connected)) ' connected) and site2channelmap for probe ' probe.elementstring() '.']);
    end;

end
