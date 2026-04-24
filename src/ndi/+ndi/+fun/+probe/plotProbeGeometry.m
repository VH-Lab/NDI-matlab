function h = plotProbeGeometry(pg, varargin)
% PLOTPROBEGEOMETRY - Plot a probe geometry
%
%  H = ndi.fun.probe.plotProbeGeometry(PG, ...)
%
%  Plots the electrode site positions and optional body contour of a
%  probe geometry.
%
%  PG can be:
%    - A struct with probe_geometry fields (site_locations_leftright,
%      site_locations_depth, etc.)
%    - An ndi.document of class 'probe_geometry'
%
%  Returns a struct H with graphics handles:
%    H.sites   - scatter handle for electrode sites
%    H.contour - line handle for body contour (empty if none)
%    H.ax      - axes handle
%
%  This function also accepts name-value pairs:
%  Parameter (default)     | Description
%  ------------------------|-------------------------------------------
%  axes (gca)              | Axes to plot into
%  marker_size (60)        | Size of site markers
%  contour_color ([0.6     | Color of body contour
%    0.6 0.6])             |
%  contour_linewidth (1.5) | Line width of body contour
%

    % parse name-value pairs
    ax = [];
    marker_size = 60;
    contour_color = [0.6 0.6 0.6];
    contour_linewidth = 1.5;

    vlt.data.assign(varargin{:});

    % extract probe_geometry struct from ndi.document if needed
    if isa(pg, 'ndi.document')
        pg = pg.document_properties.probe_geometry;
    end

    if isempty(ax)
        ax = gca;
    end

    x = pg.site_locations_leftright(:);
    y = pg.site_locations_depth(:);

    % color by shank_id if available
    if isfield(pg, 'shank_id') && ~isempty(pg.shank_id)
        c = pg.shank_id(:);
    else
        c = ones(size(x));
    end

    % plot contour if available
    h.contour = [];
    if isfield(pg, 'has_planar_contour') && pg.has_planar_contour ...
            && isfield(pg, 'contour_x') && ~isempty(pg.contour_x)
        hold(ax, 'on');
        h.contour = plot(ax, pg.contour_x(:), pg.contour_y(:), '-', ...
            'Color', contour_color, 'LineWidth', contour_linewidth);
    end

    % plot sites
    hold(ax, 'on');
    h.sites = scatter(ax, x, y, marker_size, c, 'filled', 'MarkerEdgeColor', 'k');

    % labels
    unit_str = 'um';
    if isfield(pg, 'unit') && ~isempty(pg.unit)
        unit_str = pg.unit;
    end
    xlabel(ax, ['Left/Right (' unit_str ')']);
    ylabel(ax, ['Depth (' unit_str ')']);

    title_str = 'Probe Geometry';
    if isfield(pg, 'probe_model') && ~isempty(pg.probe_model)
        title_str = pg.probe_model;
        if isfield(pg, 'manufacturer') && ~isempty(pg.manufacturer)
            title_str = [pg.manufacturer ' ' title_str];
        end
    end
    title(ax, title_str);

    % add shank colorbar if multiple shanks
    if isfield(pg, 'shank_id') && ~isempty(pg.shank_id) && numel(unique(pg.shank_id)) > 1
        cb = colorbar(ax);
        cb.Label.String = 'Shank ID';
    end

    axis(ax, 'equal');
    box(ax, 'on');

    h.ax = ax;
end
