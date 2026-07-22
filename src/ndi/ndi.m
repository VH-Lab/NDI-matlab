function varargout = ndi(varargin)
%NDI Open the NDI navigator (short alias for ndi.gui.navigator).
%
%   NDI(...) is a convenience alias that forwards all of its inputs
%   directly to NDI.GUI.NAVIGATOR and returns its output. It exists so
%   users have a short, memorable command to open the navigator.
%
%   Syntax:
%       ndi()
%       ndi(Position=[x y w h])
%       nav = ndi(...)
%
%   All inputs are passed through unchanged; see NDI.GUI.NAVIGATOR for the
%   accepted name-value arguments (Position, Visible).
%
%   See also: ndi.gui.navigator

% feval by name references the ndi.gui.navigator class unambiguously: inside
% a function file named 'ndi', the token 'ndi.gui.navigator' would otherwise
% be mis-parsed as field access on this function's name rather than the
% +ndi package path.
[varargout{1:nargout}] = feval('ndi.gui.navigator', varargin{:});
end
