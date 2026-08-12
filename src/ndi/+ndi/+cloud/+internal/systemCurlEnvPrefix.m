function prefix = systemCurlEnvPrefix()
% SYSTEMCURLENVPREFIX - Environment prefix so a system curl uses OS libraries.
%
% PREFIX = ndi.cloud.internal.systemCurlEnvPrefix()
%
% Returns a shell command prefix (char row vector) that should be prepended
% to any curl command executed with SYSTEM(). On Windows the prefix is empty.
%
% WHY THIS IS NEEDED
%   On Linux (and macOS), MATLAB prepends its own bundled library
%   directories to LD_LIBRARY_PATH for the MATLAB process, and child
%   processes launched via SYSTEM() inherit that environment. As a result
%   the operating system's curl binary can load MATLAB's bundled
%   libcurl / libssl / libcrypto instead of the OS copies. When those
%   bundled libraries are ABI-incompatible with the system curl binary, the
%   subprocess fails (symbol-lookup errors, TLS handshake failures, or an
%   immediate non-zero exit) even though nothing in the calling code changed.
%
%   This bites specifically after a MATLAB upgrade: a new release ships a new
%   bundled library set, and previously-working uploads/downloads that shell
%   out to curl start failing in environments where MATLAB controls
%   LD_LIBRARY_PATH (e.g. CI runners), while continuing to work on developer
%   machines whose libraries happen to remain compatible.
%
% WHAT THE PREFIX DOES
%   It sets LD_LIBRARY_PATH for the curl subprocess back to the value that
%   was in effect before MATLAB started. MATLAB stashes that original value
%   in the environment variable MW_ORIG_LD_LIBRARY_PATH; when that variable
%   is not present, the prefix blanks LD_LIBRARY_PATH, which makes curl fall
%   back to the system's default (ldconfig) library search path. Either way
%   the OS curl loads the OS libraries.
%
% Outputs:
%   prefix (char) - A command prefix ending in a trailing space, e.g.
%                   'LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu" ', or ''
%                   on Windows.
%
% Example:
%   prefix  = ndi.cloud.internal.systemCurlEnvPrefix();
%   command = [prefix sprintf('curl -fsSL -o "%s" "%s"', dest, url)];
%   [status, result] = system(command);
%
% See also: system

    if ispc
        prefix = '';
        return;
    end

    % MATLAB records the pre-MATLAB LD_LIBRARY_PATH here. If it is unset,
    % getenv returns '' and we blank LD_LIBRARY_PATH for the subprocess,
    % which is the safe default (the system curl then uses the OS default
    % library search path).
    originalLibPath = getenv('MW_ORIG_LD_LIBRARY_PATH');
    prefix = sprintf('LD_LIBRARY_PATH="%s" ', originalLibPath);
end
