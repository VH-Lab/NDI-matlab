function [safeFileName, isSafe] = safeLocalFilename(fileUid)
% SAFELOCALFILENAME - reduce a server-supplied file uid to a safe local filename
%
%   [SAFEFILENAME, ISSAFE] = ndi.cloud.download.internal.safeLocalFilename(FILEUID)
%
%   FILEUID arrives verbatim from the getDataset API response and is used to
%   build a local destination path. A malicious value such as
%   '../../../.matlab/R2024b/startup.m' would let a downloaded dataset write
%   outside the intended target folder -- e.g. overwrite an auto-executed MATLAB
%   startup script (path traversal).
%
%   This helper drops any directory components, keeping only the final path
%   component, so the value can be joined onto a caller-controlled target folder
%   safely. ISSAFE is false (and SAFEFILENAME is '') when the uid yields no
%   usable filename ('', '.' or '..'); callers should skip those.
%
%   Callers must still assert containment of the joined path as defence in
%   depth (fullfile does not collapse '..').
%
%   This is the MATLAB counterpart of the basename + containment guard already
%   present in NDI-python download.py; the coordinated NDI-python fix closes the
%   same hole in src/ndi/database.py get_binary_path.

    arguments
        fileUid (1,1) string
    end

    parts = regexp(char(fileUid), '[\\/]', 'split');
    safeFileName = parts{end};

    isSafe = ~isempty(safeFileName) && ~any(strcmp(safeFileName, {'.', '..'}));
    if ~isSafe
        safeFileName = '';
    end
end
