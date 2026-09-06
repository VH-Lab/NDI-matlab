function assertSingleArchiveEntry(unzippedFiles, chunkIndex, numChunks)
% ASSERTSINGLEARCHIVEENTRY - refuse a chunk archive that is not exactly one file
%
%   ndi.cloud.download.internal.assertSingleArchiveEntry(UNZIPPEDFILES, ...
%       CHUNKINDEX, NUMCHUNKS)
%
%   Errors unless UNZIPPEDFILES, the output of unzip() for one chunk of a bulk
%   document download, holds exactly one entry.
%
%   WHY THIS IS AN ERROR AND NOT A PICK. downloadDocumentCollection used to
%   take unzippedFiles{1} and ignore anything else. One JSON per archive is
%   what the server sends today, carrying every document in the chunk, but
%   nothing guarantees it and a chunk holds up to ChunkSize documents -- 2000
%   by default. If the server ever split a chunk across files, the remainder
%   would be dropped with no error anywhere: the download would simply return
%   fewer documents than were asked for. That is a silent wrong answer, the
%   same shape as VH-Lab/NDI-matlab#945.
%
%   unzip also returns archive order, so "the first entry" is not necessarily
%   the JSON even when the archive holds exactly one JSON beside something
%   incidental.
%
%   Deliberately strict rather than filtering to *.json: if the server starts
%   sending something alongside, that is a change worth seeing rather than
%   quietly tolerating.
%
%   Zero entries errors too. That case previously produced a bare indexing
%   error from {1}, which said nothing about what had gone wrong.
%
%   See also: ndi.cloud.download.downloadDocumentCollection

    arguments
        unzippedFiles cell
        chunkIndex (1,1) double
        numChunks (1,1) double
    end

    if numel(unzippedFiles) == 1
        return;
    end

    if isempty(unzippedFiles)
        found = 'none';
    else
        found = strjoin(unzippedFiles, ', ');
    end

    error('NDI:Cloud:DocumentDownloadUnexpectedArchive', ...
        ['Expected exactly one file in the document archive for chunk %d of ' ...
         '%d, found %d (%s). Reading only the first would silently discard ' ...
         'documents, so this refuses rather than guessing which one to use.'], ...
        chunkIndex, numChunks, numel(unzippedFiles), found);
end
