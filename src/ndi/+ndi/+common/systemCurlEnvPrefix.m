function prefix = systemCurlEnvPrefix()
% SYSTEMCURLENVPREFIX - Environment prefix so a system curl uses OS libraries.
%
% PREFIX = ndi.common.systemCurlEnvPrefix()
%
% Returns a shell command prefix (char row vector) that should be prepended
% to any curl command executed with SYSTEM(). On Windows the prefix is empty.
%
% WHY THIS IS NEEDED
%   On Linux, MATLAB prepends its own bundled library directories to
%   LD_LIBRARY_PATH for the MATLAB process, and child processes launched via
%   SYSTEM() inherit that environment. As a result the operating system's
%   curl binary can load MATLAB's bundled libcurl / libssl / libcrypto
%   instead of the OS copies. When those bundled libraries are
%   ABI-incompatible with the system curl binary, the subprocess fails, e.g.
%
%       curl: <matlabroot>/bin/glnxa64/libcurl.so.4: version
%       `CURL_OPENSSL_4' not found (required by curl)
%
%   even though nothing in the calling code changed. This bites specifically
%   after a MATLAB upgrade: a new release ships a new bundled library set,
%   and previously-working uploads/downloads that shell out to curl start
%   failing in environments where MATLAB controls LD_LIBRARY_PATH (e.g. CI
%   runners), while continuing to work on developer machines whose libraries
%   happen to remain compatible.
%
% WHAT THE PREFIX DOES
%   It sets LD_LIBRARY_PATH for the curl subprocess back to the value that
%   was in effect before MATLAB started. MATLAB stashes that original value
%   in the environment variable MW_ORIG_LD_LIBRARY_PATH; when that variable
%   is not present, the prefix blanks LD_LIBRARY_PATH, which makes curl fall
%   back to the system's default (ldconfig) library search path. Either way
%   the OS curl loads the OS libraries.
%
% PLATFORM NOTES
%   - Windows: returns '' (no prefix). Windows resolves DLLs via the PATH /
%     directory search order rather than LD_LIBRARY_PATH, so this specific
%     failure does not occur.
%   - macOS: the dynamic loader uses DYLD_LIBRARY_PATH, not LD_LIBRARY_PATH,
%     and System Integrity Protection strips DYLD_* variables when launching
%     system binaries such as /usr/bin/curl, so the shadowing does not
%     happen. The LD_LIBRARY_PATH prefix returned here is therefore a
%     harmless no-op on macOS.
%
% Outputs:
%   prefix (char) - A command prefix ending in a trailing space, e.g.
%                   'LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu" ', or ''
%                   on Windows.
%
% Example:
%   prefix  = ndi.common.systemCurlEnvPrefix();
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
