function h = plot(source, options)
% NDI.FUN.PROBE.GEOMETRY.PLOT - plot an electrode geometry
%
% H = NDI.FUN.PROBE.GEOMETRY.PLOT(SOURCE, ...)
%
% Plots the electrode-site layout of SOURCE, which may be:
%   - a library layout name (char/string), e.g. 'neuropixels/NP2_1shank'
%     (looked up with ndi.fun.probe.geometry.readLibrary),
%   - a probe_geometry struct (fields site_locations_leftright, etc.), or
%   - a 'probe_geometry' ndi.document.
%
% The actual drawing is done by ndi.fun.probe.plotProbeGeometry (electrode sites,
% coloured by shank, with the body contour if present). By default a new figure
% window is opened; pass an axes handle in 'axes' to draw into an existing axes.
%
% Name/value pairs:
%   axes ([])   - axes to plot into. If empty, a new figure and axes are created.
%   title ('')  - title override; defaults to the layout name / probe_model.
%
% Returns H, the struct of graphics handles from ndi.fun.probe.plotProbeGeometry.
%
% Example:
%    ndi.fun.probe.geometry.plot('neuropixels/NP2_1shank');
%
% See also: NDI.FUN.PROBE.PLOTPROBEGEOMETRY, NDI.FUN.PROBE.GEOMETRY.READLIBRARY,
%   NDI.FUN.PROBE.GEOMETRY.GET

    arguments
        source
        options.axes = []
        options.title (1,:) char = ''
    end

    % resolve SOURCE to something plotProbeGeometry accepts (a struct or a document)
    titlestr = options.title;
    if ischar(source) || isstring(source),
        name = char(source);
        geom = ndi.fun.probe.geometry.readLibrary(name);
        if isempty(titlestr), titlestr = name; end
    elseif isa(source, 'ndi.document'),
        geom = source;
        if isempty(titlestr), titlestr = 'probe geometry'; end
    elseif isstruct(source),
        geom = source;
        if isempty(titlestr) && isfield(source,'probe_model') && ~isempty(source.probe_model),
            titlestr = char(source.probe_model);
        end
    else,
        error('SOURCE must be a library name, a probe_geometry struct, or an ndi.document.');
    end

    ax = options.axes;
    if isempty(ax),
        f = figure('Name', ['Electrode geometry: ' titlestr], 'NumberTitle', 'off');
        ax = axes('Parent', f);
    end

    h = ndi.fun.probe.plotProbeGeometry(geom, 'ax', ax);

    if ~isempty(titlestr),
        title(ax, titlestr, 'Interpreter', 'none');
    end
end
