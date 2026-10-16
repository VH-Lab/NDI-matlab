function clearCommandCache()
% CLEARCOMMANDCACHE - forget where NDI-python's commands were found
%
%   ndi.python.clearCommandCache() empties the cache that
%   ndi.python.findCommand keeps, so the next lookup searches again.
%   Equivalent to ndi.python.findCommand('clear'). ndi.python.install
%   calls this after installing or uninstalling.
%
%   See also: ndi.python.findCommand, ndi.python.install

    ndi.python.findCommand('clear');
end
