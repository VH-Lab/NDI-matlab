function reader = v1FileReader(ndiDir)
%V1FILEREADER A reader of the files a v1 document attaches, for did2.convert.
%
%   READER = ndi.migrate.internal.v1FileReader(NDIDIR) returns a function
%   handle, TEXT = READER(V1BODY, FILENAME), that ndi.migrate.local passes to
%   did2.convert.v1_to_v2 as 'V1FileReader' (DID-matlab did2.convert.v1Files).
%   A migrator that must read an attached file calls it; the first is
%   gene_list_mapping, which reads `mapping.tsv` for its gene indices and row
%   count (Jess Haley, 2026-11-01, did-schema did_v2_go_forward_class_audit.md
%   [key covariate index], [mapping rows counted, indices 0-based]).
%
%   The file is found by ndi.migrate.internal.v1AttachedFile: the session's
%   file store (<NDIDIR>/files/<uid>, where v1 ingested the bytes) first, then
%   the location the document records. TEXT is the file's bytes as char. It
%   errors (NDI:migrate:v1FileNotFound) when the document attaches no such
%   file or its bytes are not on this computer; did2.convert.v1Files turns
%   the error into a carry of the whole document (for a gene-list mapping,
%   the register row for an unreadable mapping.tsv), never an empty file.
%
%   See also ndi.migrate.local, ndi.migrate.internal.v1AttachedFile.

arguments
    ndiDir (1,:) char
end

reader = @(body, filename) readOne(body, char(filename), ndiDir);
end

function text = readOne(body, filename, ndiDir)
[p, status] = ndi.migrate.internal.v1AttachedFile(body, filename, ndiDir);
if isempty(p)
    error('NDI:migrate:v1FileNotFound', '%s: %s.', filename, status);
end
fid = fopen(p, 'r');
if fid < 0
    error('NDI:migrate:v1FileNotFound', '%s: could not open %s.', filename, p);
end
c = onCleanup(@() fclose(fid));
text = fread(fid, Inf, '*char')';
end
