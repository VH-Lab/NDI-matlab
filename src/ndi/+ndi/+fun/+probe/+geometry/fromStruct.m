function [pg_doc, s2c_doc, info] = fromStruct(S, probe, geom, options)
% NDI.FUN.PROBE.GEOMETRY.FROMSTRUCT - create NDI geometry documents from a probe_geometry struct
%
% [PG_DOC, S2C_DOC] = NDI.FUN.PROBE.GEOMETRY.FROMSTRUCT(S, PROBE, GEOM, ...)
%
% Creates a 'probe_geometry' ndi.document for PROBE in the ndi.session S from GEOM,
% a struct whose fields are (a subset of) the probe_geometry fields. Missing fields
% are filled with sensible defaults: site_locations_frontback -> zeros, shank_id ->
% ones, ndim -> 2, unit -> 'um'. At minimum GEOM must contain
% site_locations_leftright and site_locations_depth.
%
% This is the shared document-builder used by NDI.FUN.PROBE.GEOMETRY.FROMKILOSORTMAP
% and NDI.FUN.PROBE.GEOMETRY.FROMLIBRARY.
%
% If a site->channel map is supplied via the 'map' option (map(i) = recording
% channel of site i; NaN for a site that is not recorded), a 'site2channelmap'
% document is also created and returned as S2C_DOC. With no map, only the
% probe_geometry document is created and S2C_DOC is []. (An electrode layout
% describes physical sites; the site->channel wiring is a property of a particular
% recording/headstage, so it is only stored when known.)
%
% Before creating the document, the number of sites in GEOM is compared against the
% number of channels the probe's epochprobemap assigns to it (from its first epoch).
% If they do not match exactly, a warning is printed (this catches the common case
% of assigning a geometry meant for a differently-sized probe). Set 'check_channels'
% to false to skip this.
%
% The optional third output INFO is a struct describing that check, so a GUI caller
% can surface it (e.g. as a uialert) rather than relying on the printed warning:
%   INFO.n_sites          - number of sites in GEOM
%   INFO.n_channels       - the probe's epochprobemap channel count ([] if unknown)
%   INFO.channel_mismatch - true if n_sites and n_channels differ
%   INFO.message          - the mismatch message ('' when there is no mismatch)
%
% Name/value pairs:
%   map ([])              - site->channel column; when non-empty, also create site2channelmap.
%   add (true)            - add the created documents to S's database.
%   replace (false)       - before adding, remove any existing probe_geometry (and its
%                            site2channelmap) for this probe, so re-assigning replaces
%                            rather than stacking a second geometry. Only acts when 'add'.
%   check_channels (true) - warn if the site count differs from the probe's
%                            epochprobemap channel count.
%   verbose (1)           - 0/1 report what was created.
%
% See also: NDI.FUN.PROBE.GEOMETRY.FROMKILOSORTMAP, NDI.FUN.PROBE.GEOMETRY.FROMLIBRARY,
%   NDI.FUN.PROBE.GEOMETRY.GET

    arguments
        S
        probe
        geom (1,1) struct
        options.map double = []
        options.add (1,1) logical = true
        options.replace (1,1) logical = false
        options.check_channels (1,1) logical = true
        options.verbose (1,1) double = 1
    end

    % Step 1: start from the full default set of probe_geometry fields
    pg = struct();
    pg.site_locations_leftright = [];
    pg.site_locations_frontback = [];
    pg.site_locations_depth = [];
    pg.shank_id = [];
    pg.contact_shape = '';
    pg.contact_shape_width = [];
    pg.contact_shape_height = [];
    pg.contact_shape_radius = [];
    pg.probe_model = '';
    pg.manufacturer = '';
    pg.ndim = 2;
    pg.unit = 'um';
    pg.has_planar_contour = 0;
    pg.contour_x = [];
    pg.contour_y = [];

    % Step 2: overlay recognized fields from GEOM
    recognized = fieldnames(pg);
    for i=1:numel(recognized),
        f = recognized{i};
        if isfield(geom,f) && ~isempty(geom.(f)),
            pg.(f) = geom.(f);
        end;
    end;

    % Step 3: normalize and fill site-location defaults
    if isempty(pg.site_locations_leftright) || isempty(pg.site_locations_depth),
        error('GEOM must contain non-empty site_locations_leftright and site_locations_depth.');
    end;
    pg.site_locations_leftright = double(pg.site_locations_leftright(:));
    pg.site_locations_depth = double(pg.site_locations_depth(:));
    n = numel(pg.site_locations_leftright);
    if numel(pg.site_locations_depth)~=n,
        error('site_locations_leftright and site_locations_depth must have the same number of elements.');
    end;

    if isempty(pg.site_locations_frontback),
        pg.site_locations_frontback = zeros(n,1);
    else,
        pg.site_locations_frontback = double(pg.site_locations_frontback(:));
    end;
    if isempty(pg.shank_id),
        pg.shank_id = ones(n,1);
    else,
        pg.shank_id = double(pg.shank_id(:));
    end;

    % Every matrix-valued probe_geometry field must be a column vector. An empty
    % optional field (e.g. contact_shape_radius on a square-contact probe, or an
    % absent contour) must be 0x1, NOT 0x0: document validation rejects a 0x0 [] as
    % "Invalid sub-field ... size 0x0" because the schema shape is [N x 1].
    matrix_fields = {'site_locations_leftright','site_locations_frontback', ...
        'site_locations_depth','shank_id','contact_shape_width', ...
        'contact_shape_height','contact_shape_radius','contour_x','contour_y'};
    for i=1:numel(matrix_fields),
        f = matrix_fields{i};
        if isempty(pg.(f)),
            pg.(f) = zeros(0,1);
        else,
            pg.(f) = double(pg.(f)(:));
        end;
    end;

    % Step 3b: sanity-check the site count against the probe's epochprobemap channels.
    % The result is both warned (for scripts / the command window) and returned in INFO
    % so a GUI caller can surface it (e.g. as a uialert) without scraping lastwarn.
    info = struct('n_sites', n, 'n_channels', [], 'channel_mismatch', false, 'message', '');
    if options.check_channels,
        nchan = probeChannelCount(probe);
        info.n_channels = nchan;
        if ~isempty(nchan) && nchan~=n,
            info.channel_mismatch = true;
            info.message = sprintf(['Electrode geometry has %d site(s) but the epochprobemap ' ...
                'for probe %s has %d channel(s); they do not match exactly.'], ...
                n, probe.elementstring(), nchan);
            warning('ndi:fun:probe:geometry:fromStruct:channelCountMismatch', '%s', info.message);
        end;
    end;

    % Step 4: optionally remove an existing geometry for this probe (replace)
    if options.add && options.replace,
        q_old = ndi.query('','isa','probe_geometry','') & ...
            ndi.query('','depends_on','probe_id',probe.id());
        oldgeom = S.database_search(q_old);
        for i=1:numel(oldgeom),
            q_s2c = ndi.query('','isa','site2channelmap','') & ...
                ndi.query('','depends_on','probe_geometry_id',oldgeom{i}.id());
            olds2c = S.database_search(q_s2c);
            if ~isempty(olds2c),
                S.database_rm(olds2c);
            end;
        end;
        if ~isempty(oldgeom),
            S.database_rm(oldgeom);
        end;
    end;

    % Step 5: create the probe_geometry document
    pg_doc = ndi.document('probe_geometry','probe_geometry',pg,'base.session_id',S.id());
    pg_doc = pg_doc.set_dependency_value('probe_id', probe.id());

    % Step 6: optionally create the site2channelmap document
    s2c_doc = [];
    if ~isempty(options.map),
        map = double(options.map(:));
        if numel(map)~=n,
            error('map must have one element per site (%d).', n);
        end;
        s2c = struct('map', map);
        s2c_doc = ndi.document('site2channelmap','site2channelmap',s2c,'base.session_id',S.id());
        s2c_doc = s2c_doc.set_dependency_value('probe_id', probe.id());
        s2c_doc = s2c_doc.set_dependency_value('probe_geometry_id', pg_doc.id());
    end;

    % Step 7: commit
    if options.add,
        S.database_add(pg_doc);
        if ~isempty(s2c_doc),
            S.database_add(s2c_doc);
        end;
    end;

    if options.verbose,
        modelstr = pg.probe_model; if isempty(modelstr), modelstr = '(unnamed)'; end;
        action = 'Created'; if options.add, action = 'Added'; end;
        extra = ''; if ~isempty(s2c_doc), extra = ' and site2channelmap'; end;
        disp([action ' probe_geometry (' modelstr ', ' int2str(n) ' sites)' extra ...
            ' for probe ' probe.elementstring() '.']);
    end;

end

function nchan = probeChannelCount(probe)
% Number of channels the probe's epochprobemap assigns to it (first epoch), or []
% if it cannot be determined (e.g. the probe has no epochs or does not expose
% getchanneldevinfo).
    nchan = [];
    try
        et = probe.epochtable();
        if isempty(et), return; end;
        [~,~,~,~,channellist] = probe.getchanneldevinfo(et(1).epoch_id);
        nchan = numel(channellist);
    catch
        nchan = [];
    end
end
