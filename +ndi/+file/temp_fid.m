function [fid,fname] = temp_fid()
    % TEMP_FID - open a new temporary file for writing
    %
    % [FID,FNAME] = TEMP_FID()
    %
    % Open a new temporary file for writing. The full name of
    % the file is returned in FNAME and the file identiifer is
    % returned in FID.
    %
    % The file is opened for writing and little-endian byte order,
    % the NDI default.
    %
    % An error is produced if the operation fails.
    %

    fname = ndi.file.temp_name();

    fid = fopen(fname,'w','l'); % open for writing, little-endian

    if fid<0
        error(['Could not open the file ' fname ' for writing.']);
    end;
