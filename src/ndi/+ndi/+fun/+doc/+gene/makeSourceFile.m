function doc = makeSourceFile(session, filename, options)
% MAKESOURCEFILE - describe, or attach, the raw file a document came from
%
%   DOC = ndi.fun.doc.gene.MAKESOURCEFILE(SESSION, FILENAME)
%   DOC = ndi.fun.doc.gene.MAKESOURCEFILE(..., 'attachFile', true)
%
%   Creates the document that the spatialGeneExpression documents point at
%   through their source_file_id dependency, so a pyramid can name the .gef
%   it was built from and a cell table the .h5ad it was segmented from.
%
%   DESCRIBING IS NOT ATTACHING, and the default is to describe. A SAW
%   .gef is ~9.4 GB; ingesting a copy of it into the database alongside
%   the pyramid derived from it would roughly double the storage to hold
%   bytes the pyramid already summarises. The document records the name,
%   the size, the checksum and the dates -- enough to identify the file,
%   verify it if it is still around, and say what a pyramid came from.
%
%   THE TWO CASES ARE TWO CLASSES, and getting that wrong is what this
%   function did until it was fixed:
%
%     attachFile false  ->  fileReference, which holds no file
%     attachFile true   ->  generic_file, which holds generic_file.ext
%
%   generic_file's schema declares generic_file.ext with mustbenotempty 1,
%   so a generic_file without its file is not a lighter version of one, it
%   is an invalid one. This function used to make exactly that, and the
%   documents passed only because DID's file validation fell through to
%   "valid" when a required file was absent. When that fail-open was fixed
%   (did-matlab #182) every affected session stopped copying into a
%   dataset, with an error naming a file_list that was in fact correct.
%   See database_documents/data/fileReference.md.
%
%   THE CHECKSUM IS THE PART WORTH HAVING. A filename tells you what
%   somebody called a file; a checksum tells you whether the file you
%   have now is the file the pyramid was built from. Two SAW runs of the
%   same chip produce files with the same name and different contents,
%   which is exactly the confusion this is meant to survive.
%
%   Inputs:
%   SESSION  - an ndi.session or ndi.dataset
%   FILENAME - path to the source file
%
%   Optional Name-Value Arguments:
%   checksum (true)     - compute the MD5. Costs a full read of the file:
%                         a minute or two for a 9.4 GB .gef, against the
%                         several minutes the ingest already spends
%                         reading it. Pass false to skip, and the field
%                         is left empty rather than filled with a
%                         placeholder that would look like a real hash.
%   attachFile (false)  - ingest a copy of the file itself, and return a
%                         generic_file document rather than a
%                         fileReference. Worth it when the source is small
%                         or when the archive is the point.
%   formatOntology ('') - an ontology term for the format, if you have
%                         one. Left EMPTY rather than guessed: a wrong
%                         term is worse than none, because it is
%                         machine-readable and will be believed.
%   documentID ('')     - a document this file is about, for the
%                         generic_file class's own document_id dependency
%
%   Outputs:
%   DOC - the ndi.document -- fileReference, or generic_file when
%         attachFile is true -- NOT yet added to the database.
%         The caller adds it, because it is normally created as part of a
%         set whose dependencies have to be wired before any of them is
%         stored.
%
%   Example:
%       src = ndi.fun.doc.gene.makeSourceFile(S, '/data/section1.gef');
%       S.database_add(src);
%
%   See also: ndi.fun.doc.gene.fromGEF, ndi.fun.doc.gene.fromCellBin,
%             ndi.fun.file.MD5, ndi.cloud.download.downloadGenericFiles

arguments
    session (1,1)
    filename (1,:) char {mustBeFile}
    options.checksum (1,1) logical = true
    options.attachFile (1,1) logical = false
    options.formatOntology (1,:) char = ''
    options.documentID (1,:) char = ''
end

[~, base, ext] = fileparts(filename);
leafname = [base ext];

% The algorithm names what the checksum IS. With no checksum there is
% nothing for it to name, and leaving 'MD5' there would advertise a hash
% that was never computed.
checksum = '';
algorithm = '';
if options.checksum
    checksum = ndi.fun.file.MD5(filename);
    algorithm = 'MD5';
end

% The dates are the file's own, not now(): a document created today from a
% file written last year should say last year. A filesystem that does not
% report one of them is not a reason to refuse the document; the checksum
% is the identifying field.
created = 0;
updated = 0;
try
    created = convertTo(ndi.fun.file.dateCreated(filename), 'datenum');
    updated = convertTo(ndi.fun.file.dateUpdated(filename), 'datenum');
catch
end

if options.attachFile
    % generic_file: the database holds the bytes, and its schema requires
    % them. Its property list has no size or algorithm fields, so it gets
    % what it declares and nothing invented.
    s = struct('filename', leafname, ...
        'formatOntology', options.formatOntology, ...
        'dateCreated', created, 'dateUpdated', updated, ...
        'checksum', checksum);
    doc = ndi.document('generic_file', 'generic_file', s) + session.newdocument();
    % delete_original 0: the source belongs to whoever gave it to us.
    doc = doc.add_file('generic_file.ext', filename, 'delete_original', 0);
else
    d = dir(filename);
    fileSize = 0;
    if ~isempty(d)
        fileSize = double(d(1).bytes);
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

end % makeSourceFile
