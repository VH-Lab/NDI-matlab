function c = cloudColors()
%NDI.GUI.CLOUDCOLORS The NDI Cloud colour palette.
%
%   C = NDI.GUI.CLOUDCOLORS() returns a struct of the NDI Cloud colours (a
%   dark navy blue, a light blue and white) so that NDI GUIs share one
%   palette instead of hardcoding RGB triplets in every widget. The colours
%   match those already used across the NDI Cloud UI
%   (ndi.gui.component.NDIProgressBar and the cloud .mlapp apps).
%
%   Fields (each a 1x3 RGB triplet in [0 1]):
%       darkBlue  - #082051, the primary NDI Cloud navy. Header bars and
%                   text on light backgrounds.
%       lightBlue - #4EA5F8, the NDI Cloud accent blue. Buttons and accents.
%       white     - pure white, for panel bodies and text on navy.
%       offWhite  - the figure-background tint used by the cloud apps.
%       okGreen   - status-badge green (a "good"/complete state, e.g. an
%                   ingested session in the navigator).
%       warnAmber - status-badge amber (a partial / attention state, e.g. a
%                   session that is linked-but-not-ingested).
%       neutralGrey - status-badge grey (a "not yet / absent" state, e.g. an
%                   on-disk session that has not been ingested).
%
%   The three status colours are the shared palette for navigator node
%   badges (see ndi.gui.nav.statusIcon): the badge letter names the check
%   and the colour names the state, so any future badge draws from these.
%
%   Example:
%       c = ndi.gui.cloudColors();
%       f = uifigure('Color', c.offWhite);
%       uibutton(f, 'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue);
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane,
%             ndi.gui.component.NDIProgressBar

    c = struct( ...
        'darkBlue',  [0.0314 0.1216 0.3176], ...   % #082051 NDI Cloud navy
        'lightBlue', [0.3059 0.6471 0.9725], ...   % #4EA5F8 NDI Cloud accent
        'white',     [1 1 1], ...                  % bodies, text on navy
        'offWhite',  [0.9922 0.9686 0.9804], ...   % figure background tint
        'okGreen',   [0.1804 0.6196 0.2784], ...   % #2E9E47 status: good/complete
        'warnAmber', [0.9020 0.6235 0.1294], ...   % #E69F21 status: partial/attention
        'neutralGrey', [0.5490 0.5804 0.6196]);    % #8C949E status: not yet / absent
end
