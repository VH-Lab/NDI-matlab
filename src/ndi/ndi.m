function ndi(varargin)
%NDI Open the NDI navigator (short alias for ndi.gui.navigator).
%
%   NDI(...) is a convenience alias that forwards all of its inputs
%   directly to NDI.GUI.NAVIGATOR. It exists so users have a short,
%   memorable command to open the navigator.
%
%   NDI deliberately returns nothing: typing "ndi" at the prompt opens the
%   window without echoing the navigator object to the command line. The
%   window keeps itself alive (the navigator stores itself in the figure's
%   guidata), so no handle needs to be captured. To obtain the object,
%   call ndi.gui.navigator directly.
%
%   Syntax:
%       ndi()
%       ndi(Position=[x y w h])
%
%   All inputs are passed through unchanged; see NDI.GUI.NAVIGATOR for the
%   accepted name-value arguments (Position, Visible).
%
%   See also: ndi.gui.navigator

% feval by name references the ndi.gui.navigator class unambiguously: inside
% a function file named 'ndi', the token 'ndi.gui.navigator' would otherwise
% be mis-parsed as field access on this function's name rather than the
% +ndi package path. The trailing semicolon (and requesting no output)
% suppresses the returned object so it is neither displayed nor available.
feval('ndi.gui.navigator', varargin{:});
end
