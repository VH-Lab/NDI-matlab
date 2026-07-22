function iconPath = statusIcon(status)
%NDI.GUI.NAV.STATUSICON Cached badge icon for a navigator session node.
%
%   ICONPATH = NDI.GUI.NAV.STATUSICON(STATUS) returns the file path of a
%   small PNG badge that summarises STATUS, suitable for a uitreenode's
%   Icon property, or '' (empty char) when STATUS conveys nothing to show.
%
%   Badge grammar ("letter names the check, colour names the state"):
%       * Each status dimension is drawn as one letter glyph:
%             ingestion -> 'i'   (more can be added; see DIMS below)
%       * The glyph colour encodes that dimension's state, from the shared
%         palette in ndi.gui.cloudColors:
%             'ingested' -> okGreen      (good / complete)
%             'linked'   -> warnAmber    (partial / attention)
%             'none'     -> neutralGrey  (not yet / absent)
%             'unknown'  -> not drawn    (the default; nothing is known yet)
%       * Dimensions whose state is 'unknown' (or missing) contribute no
%         glyph. When every dimension is unknown the badge is empty and ''
%         is returned, so a freshly-listed node carries no icon until a
%         status command computes one.
%
%   STATUS is a scalar struct whose fields are dimension names and whose
%   values are state strings, e.g. struct('ingestion','ingested'). Unknown
%   field names are ignored, so callers may pass extra bookkeeping fields.
%
%   Multiple active dimensions are composited left-to-right into a single
%   image (uitreenode has one Icon slot). The badge is rendered from a
%   compact built-in bitmap font, so it needs no toolboxes and no display -
%   it is safe to call in headless tests.
%
%   The generated PNGs are deterministic in STATUS, so they are cached on
%   disk (under a per-user temp folder) and reused; repeated calls with the
%   same STATUS return the same path without re-rendering.
%
%   Example:
%       node.Icon = ndi.gui.nav.statusIcon(struct('ingestion','ingested'));
%
%   See also: ndi.gui.cloudColors, ndi.gui.nav.datasetsPane, uitreenode

    arguments
        status (1,1) struct
    end

    % Ordered list of the status dimensions this badge knows how to draw.
    % Add a row to extend the badge (e.g. metadata completeness as 'm');
    % the glyph letter must be defined in glyphMask below.
    DIMS = struct( ...
        'field',  {'ingestion'}, ...
        'letter', {'i'});

    % Collect the active (non-unknown) dimensions, in DIMS order, and build
    % a stable cache key from them.
    letters  = {};
    colors   = {};
    keyparts = {};
    for i = 1:numel(DIMS)
        f = DIMS(i).field;
        if ~isfield(status, f)
            continue;
        end
        state = char(status.(f));
        col = stateColor(state);
        if isempty(col)
            continue;   % 'unknown' / unrecognised -> nothing to draw
        end
        letters{end+1}  = DIMS(i).letter;   %#ok<AGROW>
        colors{end+1}   = col;              %#ok<AGROW>
        keyparts{end+1} = [f '=' state];    %#ok<AGROW>
    end

    if isempty(letters)
        iconPath = '';
        return;
    end

    key      = strjoin(keyparts, '_');
    cdir     = cacheDir();
    iconPath = fullfile(cdir, ['navstatus_' key '.png']);
    if isfile(iconPath)
        return;   % already rendered for this exact status
    end

    [rgb, alpha] = renderBadge(letters, colors);

    if ~isfolder(cdir)
        mkdir(cdir);
    end
    imwrite(rgb, iconPath, 'Alpha', alpha);
end

% ------------------------------------------------------------------------
function col = stateColor(state)
    %STATECOLOR Palette colour (1x3, [0 1]) for a state, or [] to skip.
    c = ndi.gui.cloudColors();
    switch lower(char(state))
        case 'ingested'
            col = c.okGreen;
        case 'linked'
            col = c.warnAmber;
        case 'none'
            col = c.neutralGrey;
        otherwise           % 'unknown', '', or anything unrecognised
            col = [];
    end
end

% ------------------------------------------------------------------------
function d = cacheDir()
    %CACHEDIR Folder that holds the rendered, reusable badge PNGs.
    d = fullfile(tempdir, 'ndi_navstatus');
end

% ------------------------------------------------------------------------
function [rgb, alpha] = renderBadge(letters, colors)
    %RENDERBADGE Composite LETTERS (each with its COLORS) into one image.
    %   Returns an HxWx3 uint8 truecolor image RGB and an HxW uint8 ALPHA
    %   mask (255 where a glyph pixel is painted, 0 elsewhere), so the badge
    %   is transparent between and around the glyphs.
    scale   = 2;   % integer upscaling of the 5x7 bitmap cells
    padTB   = 1;   % transparent rows above and below the glyphs
    padLR   = 1;   % transparent cols at the far left/right
    gap     = 2;   % transparent cols between adjacent glyphs
    cellW   = 5;
    cellH   = 7;

    gW = cellW * scale;
    gH = cellH * scale;
    H  = gH + 2 * padTB;
    W  = padLR + numel(letters) * gW + (numel(letters) - 1) * gap + padLR;

    rgb   = zeros(H, W, 3, 'uint8');
    alpha = zeros(H, W, 'uint8');

    x = padLR;
    for i = 1:numel(letters)
        mask = glyphMask(letters{i});          % cellH x cellW logical
        mask = repelem(mask, scale, scale);    % gH x gW logical
        rows = padTB + (1:gH);
        cols = x + (1:gW);
        col  = uint8(round(colors{i} * 255));
        for ch = 1:3
            plane = rgb(rows, cols, ch);
            plane(mask) = col(ch);
            rgb(rows, cols, ch) = plane;
        end
        a = alpha(rows, cols);
        a(mask) = 255;
        alpha(rows, cols) = a;
        x = x + gW + gap;
    end
end

% ------------------------------------------------------------------------
function m = glyphMask(letter)
    %GLYPHMASK 5-wide by 7-tall logical bitmap for a supported glyph.
    %   Extend this map to add a new badge letter. '#' marks a lit pixel.
    switch lower(char(letter))
        case 'i'
            art = { ...
                '..#..'; ...
                '.....'; ...
                '..#..'; ...
                '..#..'; ...
                '..#..'; ...
                '..#..'; ...
                '..#..'};
        case 'm'
            art = { ...
                '.....'; ...
                '.....'; ...
                '#####'; ...
                '#.#.#'; ...
                '#.#.#'; ...
                '#.#.#'; ...
                '#.#.#'};
        otherwise
            error('ndi:gui:nav:statusIcon:unknownGlyph', ...
                'No bitmap defined for badge glyph ''%s''.', letter);
    end
    m = false(numel(art), numel(art{1}));
    for r = 1:numel(art)
        m(r, :) = art{r} == '#';
    end
end
