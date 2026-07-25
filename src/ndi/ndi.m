function ndi(varargin)
%NDI Open the NDI navigator (short alias for ndi.gui.navigator).
%
%   NDI(...) opens the NDI navigator window. It exists so users have a
%   short, memorable command to open the navigator.
%
%   If a navigator window is already open, NDI brings that existing window
%   to the front and reuses it rather than opening a second one; the inputs
%   are ignored in that case. Only when no navigator is open are the inputs
%   forwarded to NDI.GUI.NAVIGATOR to create a new window.
%
%   NDI deliberately returns nothing: typing "ndi" at the prompt opens (or
%   raises) the window without echoing the navigator object to the command
%   line. The window keeps itself alive (the navigator stores itself in the
%   figure's guidata), so no handle needs to be captured. To obtain the
%   object, call ndi.gui.navigator directly, or ndi.gui.navigator.findOpen
%   to retrieve an already-open one.
%
%   Syntax:
%       ndi()
%       ndi(Position=[x y w h])
%
%   When a new window is created, all inputs are passed through unchanged;
%   see NDI.GUI.NAVIGATOR for the accepted name-value arguments (Position,
%   Visible).
%
%   See also: ndi.gui.navigator, ndi.gui.navigator.findOpen

% feval by name references the ndi.gui.navigator class unambiguously: inside
% a function file named 'ndi', a token such as 'ndi.gui.navigator' would
% otherwise be mis-parsed as field access on this function's name rather than
% the +ndi package path.

% If a navigator is already open, raise and reuse it instead of opening a
% duplicate window. findOpen returns the open navigators newest last, so the
% most recently created one is brought to the front.
existing = feval('ndi.gui.navigator.findOpen');
if ~isempty(existing)
    nav = existing(end);
    if isvalid(nav) && ~isempty(nav.Figure) && isvalid(nav.Figure)
        nav.Figure.Visible = 'on';   % show it if it was created hidden
        figure(nav.Figure);          % raise and focus the existing window
        return;
    end
end

% The trailing semicolon (and requesting no output) suppresses the returned
% object so it is neither displayed nor available.
feval('ndi.gui.navigator', varargin{:});
end
