function [geom, map] = fromProbeInterface(source, options)
% NDI.FUN.PROBE.GEOMETRY.FROMPROBEINTERFACE - convert a ProbeInterface probe to an NDI layout
%
% [GEOM, MAP] = NDI.FUN.PROBE.GEOMETRY.FROMPROBEINTERFACE(SOURCE, ...)
%
% Converts a ProbeInterface probe description (the community/SpikeInterface JSON
% format, https://probeinterface.readthedocs.io) into an NDI electrode-layout struct
% GEOM (probe_geometry fields). GEOM can be written to the NDI library with
% NDI.FUN.PROBE.GEOMETRY.WRITELIBRARY or turned into documents with
% NDI.FUN.PROBE.GEOMETRY.FROMSTRUCT.
%
% SOURCE is either a path to a ProbeInterface .json file or an already-decoded
% struct (from jsondecode). A ProbeInterface file may contain several probes; by
% default the first is used (see 'probe_index').
%
% Field mapping (ProbeInterface -> probe_geometry):
%   contact_positions(:,1)  -> site_locations_leftright
%   contact_positions(:,2)  -> site_locations_depth
%   contact_positions(:,3)  -> site_locations_frontback  (only if ndim >= 3)
%   shank_ids               -> shank_id (string ids are mapped to integers 1..K)
%   si_units                -> unit (coordinates are converted to microns by default)
%   annotations.model_name/name -> probe_model
%   annotations.manufacturer    -> manufacturer
%   contact_shapes/params   -> contact_shape, contact_shape_radius/width/height
%   probe_planar_contour    -> contour_x/contour_y (+ has_planar_contour)
%
% MAP is the site->channel map derived from ProbeInterface device_channel_indices
% (converted from 0-based to 1-based; contacts with -1 become NaN), suitable for the
% 'map' option of NDI.FUN.PROBE.GEOMETRY.FROMSTRUCT/FROMLIBRARY. MAP is [] if the
% ProbeInterface probe has no device_channel_indices.
%
% Name/value pairs:
%   probe_index (1)       - which probe in the file to convert.
%   convert_to_um (true)  - scale coordinates to microns based on si_units.
%
% See also: NDI.FUN.PROBE.GEOMETRY.WRITELIBRARY, NDI.FUN.PROBE.GEOMETRY.FROMSTRUCT,
%   NDI.FUN.PROBE.GEOMETRY.FROMLIBRARY

    arguments
        source
        options.probe_index (1,1) double = 1
        options.convert_to_um (1,1) logical = true
    end

    % Step 1: decode
    if ischar(source) || isstring(source),
        source = char(source);
        if ~isfile(source),
            error('ProbeInterface file not found: %s.', source);
        end;
        pidata = jsondecode(fileread(source));
    elseif isstruct(source),
        pidata = source;
    else,
        error('SOURCE must be a ProbeInterface .json file path or a decoded struct.');
    end;

    if ~isfield(pidata,'probes'),
        error('This does not look like a ProbeInterface file (no ''probes'' field).');
    end;
    probes = pidata.probes;
    if iscell(probes),
        if options.probe_index>numel(probes), error('probe_index %d out of range (%d probes).', options.probe_index, numel(probes)); end;
        p = probes{options.probe_index};
    else, % struct array
        if options.probe_index>numel(probes), error('probe_index %d out of range (%d probes).', options.probe_index, numel(probes)); end;
        p = probes(options.probe_index);
    end;

    % Step 2: positions
    if ~isfield(p,'contact_positions') || isempty(p.contact_positions),
        error('ProbeInterface probe has no contact_positions.');
    end;
    pos = double(p.contact_positions);
    if isfield(p,'ndim') && ~isempty(p.ndim), ndim = double(p.ndim); else, ndim = size(pos,2); end;

    scale = 1;
    unit = 'um';
    if isfield(p,'si_units') && ~isempty(p.si_units),
        unit = char(p.si_units);
    end;
    if options.convert_to_um,
        switch lower(unit),
            case {'um','micron','microns'}, scale = 1;
            case 'mm', scale = 1e3;
            case 'm',  scale = 1e6;
            otherwise, scale = 1; % unknown unit: leave as-is
        end;
        if scale~=1, unit = 'um'; end;
    end;

    n = size(pos,1);
    geom = struct();
    geom.site_locations_leftright = pos(:,1) * scale;
    if size(pos,2)>=2, geom.site_locations_depth = pos(:,2) * scale; else, geom.site_locations_depth = zeros(n,1); end;
    if ndim>=3 && size(pos,2)>=3,
        geom.site_locations_frontback = pos(:,3) * scale;
    else,
        geom.site_locations_frontback = zeros(n,1);
    end;
    geom.ndim = min(ndim,3);
    geom.unit = unit;

    % Step 3: shank ids (strings -> integers)
    geom.shank_id = ones(n,1);
    if isfield(p,'shank_ids') && ~isempty(p.shank_ids),
        sid = p.shank_ids;
        if isnumeric(sid),
            geom.shank_id = double(sid(:));
        else,
            sid = cellstr(string(sid));
            [~,~,ic] = unique(sid,'stable');
            geom.shank_id = ic(:);
        end;
    end;

    % Step 4: annotations (model/manufacturer)
    geom.probe_model = '';
    geom.manufacturer = '';
    if isfield(p,'annotations') && isstruct(p.annotations),
        a = p.annotations;
        if isfield(a,'model_name') && ~isempty(a.model_name), geom.probe_model = char(string(a.model_name));
        elseif isfield(a,'name') && ~isempty(a.name), geom.probe_model = char(string(a.name)); end;
        if isfield(a,'manufacturer') && ~isempty(a.manufacturer), geom.manufacturer = char(string(a.manufacturer)); end;
    end;

    % Step 5: contact shapes and their parameters
    if isfield(p,'contact_shapes') && ~isempty(p.contact_shapes),
        shapes = cellstr(string(p.contact_shapes));
        u = unique(shapes,'stable');
        geom.contact_shape = char(strjoin(u,','));
    end;
    if isfield(p,'contact_shape_params') && ~isempty(p.contact_shape_params),
        [rad,wid,hei] = deal(nan(n,1));
        sp = p.contact_shape_params;
        for i=1:n,
            if iscell(sp), si = sp{i}; elseif numel(sp)>=i, si = sp(i); else, si = sp; end;
            if isstruct(si),
                if isfield(si,'radius') && ~isempty(si.radius), rad(i) = double(si.radius)*scale; end;
                if isfield(si,'width') && ~isempty(si.width), wid(i) = double(si.width)*scale; end;
                if isfield(si,'height') && ~isempty(si.height), hei(i) = double(si.height)*scale; end;
            end;
        end;
        if any(~isnan(rad)), geom.contact_shape_radius = rad; end;
        if any(~isnan(wid)), geom.contact_shape_width = wid; end;
        if any(~isnan(hei)), geom.contact_shape_height = hei; end;
    end;

    % Step 6: planar contour
    if isfield(p,'probe_planar_contour') && ~isempty(p.probe_planar_contour),
        c = double(p.probe_planar_contour);
        geom.has_planar_contour = 1;
        geom.contour_x = c(:,1) * scale;
        if size(c,2)>=2, geom.contour_y = c(:,2) * scale; end;
    end;

    % Step 7: site -> channel map from device_channel_indices (0-based, -1 => none)
    map = [];
    if isfield(p,'device_channel_indices') && ~isempty(p.device_channel_indices),
        dci = double(p.device_channel_indices(:));
        map = dci + 1;      % 0-based -> 1-based
        map(dci<0) = NaN;   % -1 => not connected
    end;

end
