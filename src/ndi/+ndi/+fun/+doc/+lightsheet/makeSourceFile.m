function doc = makeSourceFile(session, zarrPath)
% NDI.FUN.DOC.LIGHTSHEET.MAKESOURCEFILE - fileReference for an OME-Zarr store
%
%   DOC = NDI.FUN.DOC.LIGHTSHEET.MAKESOURCEFILE(SESSION, ZARRPATH)
%
%   Creates and adds a FILEREFERENCE document naming the OME-Zarr store
%   at ZARRPATH. NDI.FUN.DOC.LIGHTSHEET.FROMOMEZARR calls this to obtain
%   the id it stores in `source_file_id` on the pyramid and level
%   documents.
%
%   The store's per-chunk files are many, so this does not checksum the
%   full tree; it records the directory itself as the reference,
%   matching how spatialGeneExpression stores its GEF source.

    arguments
        session (1,1)
        zarrPath (1,:) char
    end

    if ~isfolder(zarrPath)
        error('NDI:lightsheet:makeSourceFile:noSuchStore', ...
            'OME-Zarr store not found at %s.', zarrPath);
    end

    d = dir(zarrPath);
    d = d(~ismember({d.name}, {'.', '..'}));
    totalBytes = sum([d.bytes]);
    if isempty(totalBytes)
        totalBytes = 0;
    end

    [absPath, ~, ~] = fileparts(fullfile(zarrPath, '.'));
    [~, storeName, storeExt] = fileparts(strip(absPath, 'right', filesep));
    fileName = [storeName storeExt];

    doc = session.newdocument('fileReference', ...
        'fileReference', struct( ...
            'filename', fileName, ...
            'originalPath', absPath, ...
            'formatOntology', 'OME-NGFF v0.4 (OME-Zarr)', ...
            'dateCreated', posixtime(datetime('now', 'TimeZone', 'UTC')), ...
            'dateUpdated', posixtime(datetime('now', 'TimeZone', 'UTC')), ...
            'fileSize', totalBytes, ...
            'checksum', '', ...
            'checksumAlgorithm', 'MD5'));

    session.database_add(doc);
end
