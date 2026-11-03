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
    error('NDI:daq:reader:ingestedFileNotFound', ...
        'Epoch %s: the data body for %s has no member %s (%s).', ...
        A.epoch_id, series, member, ME.message);
end
data = f.fread(Inf, 'uint8');
S.database_closebinarydoc(f);
fid = fopen(tname, 'wb', 'ieee-le');
fwrite(fid, data, 'uint8');
fclose(fid);
end
