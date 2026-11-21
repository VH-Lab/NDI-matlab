function t = ingestedSplitTime(S, A, filename)
%INGESTEDSPLITTIME One segment of a split v1 time group, rebuilt from its time values.
%
%   T = ndi.vintage.ingestedSplitTime(S, A, FILENAME) reads the v1 time
%   segment FILENAME (`ti_group<g>_seg.nbf_<m>`) of the ingested epoch A
%   (ndi.vintage.ingestedArchive) in session S, when that time group was
%   split, one time value per time channel: Decided by Jess Haley,
%   2026-11-19 [time group with several time channels split] (did-schema
%   did_v2_standing_wiring_plan.md): "when an ingested archive's one uneven
%   time group file holds several time channels, each time channel becomes
%   its own keyed `time` value" (ndi.migrate.internal.ingestedArchiveBodies).
%   Each time value's sampled_body holds one column of the v1 file, member
%   body_data_<m-1> its segment m, compressed as the v1 ingest compresses
%   time (ndi.compress.compress_time); ndi.vintage.ingestedArchiveSeries
%   orders them by time channel, the order NDI's writer lists them in and so
%   the v1 file's column order.
%
%   T has one column per time channel, as ndi.compress.expand_time returns
%   the v1 file. Its values are what the bodies hold: seconds from the
%   epoch's start ([clock only on the time reference]); the reader adds the
%   epoch's start (ndi.daq.reader.mfdaq/readchannels_epochsamples_ingested),
%   as for a time group of one time channel.
%
%   Raises NDI:daq:reader:ingestedFileNotFound when the series has no split
%   body, or a body has no member for the segment, and
%   NDI:daq:reader:ingestedSplitTimeLengths when the columns' segments differ
%   in length.
%
%   See also ndi.vintage.ingestedArchiveSeries, ndi.vintage.ingestedArchiveFile,
%            ndi.daq.reader.mfdaq.

arguments
    S
    A (1,1) struct
    filename (1,:) char
end

tok = regexp(filename, '^(ti_group\d+_seg\.nbf_)(\d+)$', 'tokens', 'once');
if isempty(tok)
    error('NDI:daq:reader:ingestedFileNotFound', ...
        'Epoch %s: %s is not a segment of an ingested time group.', A.epoch_id, filename);
end
series = [tok{1} '#'];
member = sprintf('body_data_%d', str2double(tok{2}) - 1);
if ~isKey(A.bodies, series) || ~strcmp(A.bodies(series).kind, 'split_time')
    error('NDI:daq:reader:ingestedFileNotFound', ...
        'Epoch %s has no split time group for the ingested file %s (series %s).', ...
        A.epoch_id, filename, series);
end
e = A.bodies(series);
cols = cell(1, numel(e.docs));
for c = 1:numel(e.docs)
    stem = ndi.file.temp_name();
    tname = [stem '.nbf.tgz'];
    try
        f = S.database_openbinarydoc(e.docs{c}, member);
    catch ME
        error('NDI:daq:reader:ingestedFileNotFound', ...
            'Epoch %s: the time value body of time channel t%d (series %s) has no member %s (%s).', ...
            A.epoch_id, e.numbers(c), series, member, ME.message);
    end
    data = f.fread(Inf, 'uint8');
    S.database_closebinarydoc(f);
    fid = fopen(tname, 'wb', 'ieee-le');
    fwrite(fid, data, 'uint8');
    fclose(fid);
    cleaner = onCleanup(@() deleteIfThere(tname)); %#ok<NASGU>
    cols{c} = ndi.compress.expand_time(stem);
    clear cleaner;
end
lens = cellfun(@(x) size(x, 1), cols);
if any(lens ~= lens(1))
    error('NDI:daq:reader:ingestedSplitTimeLengths', ...
        'Epoch %s: the time channels of %s hold %s sample(s) in segment %s; one segment holds the same count in every column.', ...
        A.epoch_id, series, mat2str(lens), tok{2});
end
t = cat(2, cols{:});
end

function deleteIfThere(f)
if isfile(f); delete(f); end
end
