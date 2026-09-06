function doc = makeSourceFile(session, filename, options)
% MAKESOURCEFILE - describe a raw source file as a generic_file document
%
%   DOC = ndi.fun.doc.gene.MAKESOURCEFILE(SESSION, FILENAME)
%   DOC = ndi.fun.doc.gene.MAKESOURCEFILE(..., 'attachFile', true)
%
%   Creates the generic_file document that the spatialGeneExpression
%   documents point at through their source_file_id dependency, so a
%   pyramid can name the .gef it was built from and a cell table the
%   .h5ad it was segmented from.
%
%   DESCRIBING IS NOT ATTACHING, and the default is to describe. A SAW
%   .gef is ~9.4 GB; ingesting a copy of it into the database alongside
%   the pyramid derived from it would roughly double the storage to hold
%   bytes the pyramid already summarises. The document records the name,
%   the checksum and the dates -- enough to identify the file, verify it
%   if it is still around, and say what a pyramid came from. Pass
%   attachFile true when the source is small enough to be worth keeping,
%   or when the archive is the point.
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
%   attachFile (false)  - also ingest a copy of the file itself
%   formatOntology ('') - an ontology term for the format, if you have
%                         one. Left EMPTY rather than guessed: a wrong
%                         term is worse than none, because it is
%                         machine-readable and will be believed.
%   documentID ('')     - a document this file is about, for the
%                         generic_file class's own document_id dependency
%
%   Outputs:
%   DOC - the generic_file ndi.document, NOT yet added to the database.
%         The caller adds it, because it is normally created as part of a
%         set whose dependencies have to be wired before any of them is
%         stored.
%
%   Example:
%       src = ndi.fun.doc.gene.makeSourceFile(S, '/data/section1.gef');
%       S.database_add(src);
%
%   See also: ndi.fun.doc.gene.fromGEF, ndi.fun.doc.gene.fromCellBin,
%             ndi.fun.file.MD5

arguments
    session (1,1)
    filename (1,:) char {mustBeFile}
    options.checksum (1,1) logical = true
    options.attachFile (1,1) logical = false
    options.formatOntology (1,:) char = ''
    options.documentID (1,:) char = ''
end

[~, base, ext] = fileparts(filename);

s = struct('filename', [base ext], ...
    'formatOntology', options.formatOntology, ...
    'dateCreated', '', 'dateUpdated', '', 'checksum', '');

% The dates are the file's own, not now(): a document created today from a
% file written last year should say last year.
try
    s.dateCreated = convertTo(ndi.fun.file.dateCreated(filename), 'datenum');
    s.dateUpdated = convertTo(ndi.fun.file.dateUpdated(filename), 'datenum');
catch
    % A filesystem that does not report one of them is not a reason to
    % refuse the document; the checksum is the identifying field.
end

if options.checksum
    s.checksum = ndi.fun.file.MD5(filename);
end

doc = ndi.document('generic_file', 'generic_file', s) + session.newdocument();

if ~isempty(options.documentID)
    doc = doc.set_dependency_value('document_id', options.documentID);
end

if options.attachFile
    % delete_original 0: the source belongs to whoever gave it to us.
    doc = doc.add_file('generic_file.ext', filename, 'delete_original', 0);
end

end % makeSourceFile
