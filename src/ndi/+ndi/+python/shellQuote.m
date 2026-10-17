function s = shellQuote(str, options)
% SHELLQUOTE - one argument, quoted for the shell SYSTEM uses
%
%   S = ndi.python.shellQuote(STR) returns STR quoted as a single
%   argument: single quotes on Linux and macOS (an embedded single quote
%   becomes '\''), double quotes on Windows (an embedded double quote is
%   doubled). Paths with spaces, such as Windows user folders, then stay
%   one argument.
%
%   Optional Name-Value Arguments:
%     IsWindows - quote for cmd.exe (default ispc).
%
%   Example:
%     ndi.python.shellQuote('/home/me/my data')   % '/home/me/my data'
%
%   See also: ndi.python.commandLine, ndi.python.launch

    arguments
        str {mustBeTextScalar}
        options.IsWindows (1,1) logical = ispc
    end

    str = char(str);
    if options.IsWindows
        s = ['"' strrep(str, '"', '""') '"'];
    else
        s = ['''' strrep(str, '''', '''\''''') ''''];
    end
end
