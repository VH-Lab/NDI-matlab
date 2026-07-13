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
        'offWhite',  [0.9922 0.9686 0.9804]);      % figure background tint
end
