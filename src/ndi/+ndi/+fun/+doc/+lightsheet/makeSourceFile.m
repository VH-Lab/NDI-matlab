function doc = makeSourceFile(session, filename, options)
% MAKESOURCEFILE - describe, or attach, the source OME-Zarr a pyramid came from
%
%   DOC = ndi.fun.doc.lightsheet.MAKESOURCEFILE(SESSION, FILENAME)
%   DOC = ndi.fun.doc.lightsheet.MAKESOURCEFILE(..., 'attachFile', true)
%
%   Creates the document that lightsheetZarrPyramid points at through
%   its source_file_id dependency, so a pyramid can name the store it
%   was built from and a later reader can verify it is looking at the
%   same bytes.
%
%   DESCRIBING IS NOT ATTACHING, and the default is to describe. An
%   OME-Zarr store is a directory tree of tens to hundreds of GB;
%   ingesting a copy of it alongside the pyramid derived from it would
%   double the storage to hold bytes the pyramid already summarises.
%   The document records the name, the size, the checksum and the dates
%   -- enough to identify the file, verify it if it is still around,
%   and say what a pyramid came from.
%
%   The two cases are two classes, mirroring the +gene package's
%   makeSourceFile after issue #981 taught the same lesson:
%
%     attachFile false  ->  fileReference, which holds no file
%     attachFile true   ->  generic_file, which holds generic_file.ext
%
%   generic_file's schema declares generic_file.ext with mustbenotempty
%   1, so a generic_file without its file is not a lighter version of
%   one, it is an invalid one.
%
%   THE CHECKSUM IS THE PART WORTH HAVING. A filename tells you what
%   somebody called a file; a checksum tells you whether the file you
%   have now is the file the pyramid was built from.
%
%   FILENAME may be a file or a directory. For an OME-Zarr store
%   (a directory tree) the checksum, when requested, is computed over
%   the store's `.zattrs` file, which is small and identifies the
%   multiscales layout uniquely; the alternative -- walking every
%   chunk file -- would cost the full pyramid read that the caller
%   is trying to avoid.
%
%   Optional Name-Value Arguments:
%   checksum (true)     - compute the MD5 identifying fingerprint. For a
%                         directory (an OME-Zarr store) this is the MD5
%                         of .zattrs; for a plain file it is the MD5
%                         of the file. Pass false to skip; the field is
%                         left empty rather than filled with a
%                         placeholder.
%   attachFile (false)  - ingest a copy of the file itself, and return a
%                         generic_file document rather than a
%                         fileReference. Only valid for a plain file --
%                         attaching a directory tree is not supported.
%   formatOntology ('') - an ontology term for the format, if you have
%                         one. Left EMPTY rather than guessed.
%   documentID ('')     - a document this file is about, for the
%                         class's own document_id dependency.
%
%   Outputs:
%   DOC - the ndi.document -- fileReference, or generic_file when
%         attachFile is true -- NOT yet added to the database. The
%         caller adds it, because it is normally created as part of a
%         set whose dependencies have to be wired before any of them is
%         stored.
%
%   Example:
%       src = ndi.fun.doc.lightsheet.makeSourceFile(S, '/data/vol.ome.zarr');
%       S.database_add(src);
%
%   See also: ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.gene.makeSourceFile,
%             ndi.fun.file.MD5

    arguments
        session (1,1)
        filename (1,:) char
        options.checksum (1,1) logical = true
        options.attachFile (1,1) logical = false
        options.formatOntology (1,:) char = ''
        options.documentID (1,:) char = ''
    end

    isDir = isfolder(filename);
    isFile = ~isDir && isfile(filename);
    if ~isDir && ~isFile
        error('NDI:lightsheet:makeSourceFile:noSuchPath', ...
            'No file or directory at %s.', filename);
    end
    if options.attachFile && isDir
        error('NDI:lightsheet:makeSourceFile:cannotAttachDirectory', ...
            ['attachFile is only valid for a plain file. An OME-Zarr ' ...
             'store is a directory tree and is described, not ingested.']);
    end

    [~, base, ext] = fileparts(filename);
    leafname = [base ext];

    checksum = '';
    algorithm = '';
    if options.checksum
        if isDir
            zattrs = fullfile(filename, '.zattrs');
            if isfile(zattrs)
                checksum = ndi.fun.file.MD5(zattrs);
            end
        else
            checksum = ndi.fun.file.MD5(filename);
        end
        if ~isempty(checksum)
            algorithm = 'MD5';
        end
    end

    created = 0;
    updated = 0;
    try
        created = convertTo(ndi.fun.file.dateCreated(filename), 'datenum');
        updated = convertTo(ndi.fun.file.dateUpdated(filename), 'datenum');
    catch
    end

    if options.attachFile
        s = struct('filename', leafname, ...
            'formatOntology', options.formatOntology, ...
            'dateCreated', created, 'dateUpdated', updated, ...
            'checksum', checksum);
        doc = ndi.document('generic_file', 'generic_file', s) + session.newdocument();
        doc = doc.add_file('generic_file.ext', filename, 'delete_original', 0);
    else
        fileSize = 0;
        if isFile
            d = dir(filename);
            if ~isempty(d)
                fileSize = double(d(1).bytes);
            end
        end
        s = struct('filename', leafname, ...
            'originalPath', filename, ...
            'formatOntology', options.formatOntology, ...
            'dateCreated', created, 'dateUpdated', updated, ...
            'fileSize', fileSize, ...
            'checksum', checksum, ...
            'checksumAlgorithm', algorithm);
        doc = ndi.document('fileReference', 'fileReference', s) + session.newdocument();
    end

    if ~isempty(options.documentID)
        doc = doc.set_dependency_value('document_id', options.documentID);
    end
end
