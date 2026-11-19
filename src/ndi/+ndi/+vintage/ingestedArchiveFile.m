function [tname, tname_without_extension] = ingestedArchiveFile(S, A, filename, extension)
%INGESTEDARCHIVEFILE Copy one v1 ingested file out of its v2 data body.
%
%   [TNAME, TNAME_WITHOUT_EXTENSION] = ndi.vintage.ingestedArchiveFile( ...
%       SESSION, A, FILENAME, EXTENSION)
%   is ndi.database.fun.copydocfile2temp for an archive A read by
%   ndi.vintage.ingestedArchive: FILENAME is the name the v1 ingested
%   document attached the file under (`ai_group1_seg.nbf_3`,
%   `evmktx_group1_seg.nbf_1`), and its bytes are member body_data_<s-1> of
%   the body whose `data_body.filename` is the series name
%   (`ai_group1_seg.nbf_#`): DID-matlab did2.convert.resolveEpochProbemap
%   carries v1 segment s as member s-1, and
%   ndi.migrate.internal.ingestedArchiveBodies keeps the files as they are.
%   The copy is written to a temporary file named TNAME
%   (TNAME_WITHOUT_EXTENSION followed by EXTENSION), as copydocfile2temp
%   writes it, so NDI's expanders read it unchanged.
%
%   MEMBER NAMES. The schema's names (`body_data_0`, `body_data_1`, ... in
%   segment order) are read first: did-schema [ingested body members use the
%   schema's names] and [migrated body members renamed] (Jess Haley,
%   2026-11-17); pass 1 already writes them. A body whose member is still
%   named by NDI's own file name (FILENAME itself, `ai_group1_seg.nbf_3`) is
%   read under that name, so both shapes read the same.
%
%   Raises NDI:daq:reader:ingestedFileNotFound when the archive has no such
%   series or member.
%
%   See also ndi.vintage.ingestedArchive, ndi.database.fun.copydocfile2temp.

arguments
    S
    A (1,1) struct
    filename (1,:) char
    extension (1,:) char = ''
end

tok = regexp(filename, '^(.*_seg\.nbf_)(\d+)$', 'tokens', 'once');
if isempty(tok)
    series = filename;
    member = 'body_data_0';
else
    series = [tok{1} '#'];
    member = sprintf('body_data_%d', str2double(tok{2}) - 1);
end
if ~isKey(A.bodies, series)
    error('NDI:daq:reader:ingestedFileNotFound', ...
        'Epoch %s has no v2 data body for the ingested file %s (series %s).', ...
        A.epoch_id, filename, series);
end
b = A.bodies(series);
tname_without_extension = ndi.file.temp_name();
tname = [tname_without_extension extension];
try
    f = S.database_openbinarydoc(b.doc, member);
catch ME
    if ~any(strcmp(memberNamesOf(b.doc), filename))
        error('NDI:daq:reader:ingestedFileNotFound', ...
            'Epoch %s: the data body for %s has no member %s (%s).', ...
            A.epoch_id, series, member, ME.message);
    end
    % the member still carries NDI's own name
    f = S.database_openbinarydoc(b.doc, filename);
end
data = f.fread(Inf, 'uint8');
S.database_closebinarydoc(f);
fid = fopen(tname, 'wb', 'ieee-le');
fwrite(fid, data, 'uint8');
fclose(fid);
end

function names = memberNamesOf(doc)
% the member names the body's files.file_info records
names = {};
try
    p = doc.document_properties;
catch
    return;
end
if ~isfield(p, 'files') || ~isstruct(p.files) || ~isfield(p.files, 'file_info')
    return;
end
fi = p.files.file_info;
if isstruct(fi); fi = num2cell(fi); end
for k = 1:numel(fi)
    if isstruct(fi{k}) && isfield(fi{k}, 'name'); names{end+1} = char(fi{k}.name); end %#ok<AGROW>
end
end
