function [structs, report, removed] = ingestedArchiveBodies(structs, ndiDir, v1Bodies)
%INGESTEDARCHIVEBODIES Turn each migrated v1 ingested mfdaq channel group into
%   one sampled_body whose channel list is covariates, when the bytes are on
%   this computer.
%
%   [STRUCTS, REPORT, REMOVED] = ndi.migrate.internal.ingestedArchiveBodies( ...
%       STRUCTS, NDIDIR, V1BODIES)
%   takes the migrated document bodies (structs, did2.document/toStruct) of
%   the session whose .ndi directory is NDIDIR, and the session's v1 bodies
%   V1BODIES (structs or JSON text; only the v1
%   `daqreader_mfdaq_epochdata_ingested` documents are read, for their
%   segment lengths and epoch start). It returns STRUCTS with every channel
%   group it could read REPLACED, id preserved, and REMOVED, the ids of the
%   bodies whose content is now carried elsewhere (the caller drops them).
%   A document made here (the `time` value of an unevenly spaced time
%   group, an unpacked event, marker or text channel's documents, below) is
%   APPENDED to STRUCTS; its id is in its archive's REPORT.changed_groups and
%   in REPORT.added_ids.
%
%   Decided by Jess Haley, 2026-11-01 [ingested archives are sampled bodies]
%   (did-schema did_v2_go_forward_class_audit.md): "a v1 ingested channel
%   group (`ai/ao/ax/di/do/ti_group<g>_seg.nbf_<s>`) becomes one
%   `sampled_body` per group, the same shape NDI v2's ingest writes ([V2
%   ingest is one sampled body per channel group]); its channel list (channel
%   numbers, offset, scale; the sample rate as the time axis's spacing) is
%   covariates on that body, not the `channel_list.bin` file." Pass 1
%   (did2.convert.resolveEpochProbemap, "One opaque_body per attached
%   series") carries each series as an opaque_body; this second-pass step,
%   which can read NDI's files, converts them:
%
%     opaque_body  `<p>_group<g>_seg.nbf_#`, p in ai ao ax di do, members
%                  body_data_0..N-1 = v1 segments 1..N
%       ->  sampled_body
%             dimensions  0  time     (om:Time), n = the samples in the
%                                     group, chunk = the v1 segment length
%                                     (the archive's sample_analog_segment
%                                     or sample_digital_segment; [segment
%                                     length is the time chunk])
%                         1  channel  (NCIT:C44170), n = the group's channels
%             covariates  time along 0: origin 0, spacing 1/sample rate,
%                         second ([evenly spaced time is a covariate]; v1
%                         reads sample s at t0 + (s-1)/rate, so origin 0 is
%                         the epoch's start: [clock only on the time
%                         reference], no clock on the body)
%                         channel number along 1: count (v1 `number`)
%                         offset along 1: quantity (v1 `offset`), no unit
%                         scale along 1: quantity (v1 `scale`), in volts
%                                     per count where the reader defines
%                                     its output unit (below)
%             conditions  Channel (NCIT:C44170) = the group's channel type
%                         term ([channel types]; ndi.vintage.channelTypes)
%             datum_order 'F' (time fastest, as NDI's compressors take a
%                         samples-by-channels array)
%             format, compression, filename, files: unchanged
%
%     The time group `ti_group<g>_seg.nbf_#`: when every time sample is
%     t0 + (k-1)/rate (to a millionth of a sample), it adds nothing the
%     groups' time covariate does not say ([evenly spaced time is a
%     covariate]: "stores no body for it") and its body is REMOVED.
%
%     When it is not evenly spaced (counted `time_not_evenly_spaced`):
%     Decided by Jess Haley, 2026-11-03 [uneven time is a keyed time value]
%     (did-schema did_v2_go_forward_class_audit.md): "the timestamps are one
%     standalone `time` value document (`data_body: true`) whose
%     `sampled_body` (one `time` dimension, seconds) holds them; every
%     channel-group body of that recording lists it in `key_id` and its time
%     covariate (along the time dimension) is `key` to it, so sample k's time
%     is position k of that value; no time observation is minted". So:
%
%       a new `time` value   data_body true, no inline value, no time
%                            reference (the decision's accepted limitation),
%                            APPENDED to STRUCTS
%       opaque_body `ti_group<g>_seg.nbf_#`  ->  sampled_body owned by that
%                            value, id preserved: dimension 0 time (om:Time),
%                            n = the time samples, chunk = the v1 segment
%                            length (sample_analog_segment, as the v1 ingest
%                            cuts time segments); format, compression,
%                            filename unchanged; files unchanged when the
%                            epoch starts at 0, else NEW files (below)
%       each channel group   as above, but its time covariate is `key` 0 and
%                            its `key_id` the time value
%
%     SEVERAL TIME GROUPS. Decided by Jess Haley, 2026-11-19 [uneven time
%     groups and mismatches] (did-schema did_v2_standing_wiring_plan.md):
%     "(1) an ingested archive with several uneven time groups is
%     converted, one `time` value per time group, each channel group keyed
%     to the time group it uses, as the channel list pairs them; (2) a time
%     channel whose sample count differs from the data it times is
%     malformed: the archive is kept as v1, counted ... and reported". So
%     each uneven time group `ti_group<g>` (one time channel) gets its own
%     time value (counted `uneven_time_values`), and a channel group keys
%     to the time value of the time channel its rows' v1 time_channel names
%     (all the same); one that names an evenly spaced time group's channel
%     keeps its evenly spaced time covariate. A channel group whose rows name
%     no time channel of the archive (NaN, several, or one with no row) keys
%     to the archive's time channel when it has exactly one (the
%     single-group path, NDI-matlab #1226); otherwise the archive is LEFT as
%     pass 1 wrote it, counted `uneven_time_unpaired_kept`. A channel group
%     whose sample count is not its time channel's is malformed: the archive
%     is LEFT, counted `uneven_time_mismatch_kept`. Each archive left for
%     its uneven time is listed in REPORT.uneven_time_kept {kind
%     ('mismatch' | 'unpaired'), archive_id (the v1 archive), group_body_id,
%     time_body_id, reason} (first reason: `first_uneven_time_kept_reason`),
%     and is also `unconvertible`. A time group of several time channels
%     that is not evenly spaced is `unconvertible` (no decision says which
%     channel a group keys to).
%
%     The time value's samples are seconds from the epoch's start. [clock
%     only on the time reference] (Jess Haley, 2026-11-01): a body's time
%     axis counts "the epoch-relative sample times when not evenly spaced";
%     the v1 time segments hold times on the epoch's clock (sample k is
%     t0 + ... there, t0 the v1 archive's t0_t1(1)). When t0 is 0 they are
%     the epoch-relative times and the body keeps pass 1's files. When it
%     is not (counted `uneven_time_rebased`), [uneven time rewritten from
%     the epoch start] (Jess Haley, 2026-11-12): the time group's samples
%     are rewritten as t - t0 into NEW files, one per v1 segment, each
%     compressed as the v1 ingest compressed it (ndi.compress.compress_time,
%     ndi.daq.reader.mfdaq/ingest_epochfiles) and written into the store,
%     <NDIDIR>/files/<new uid>, as members body_data_0..N-1 of the time
%     value's sampled_body; every channel group keys to it as above. The
%     v1 files stay where they are (a migration deletes no file). The v1
%     epoch start stays on the recording observation's time references,
%     where pass 1 wrote it, so reading sample k through the time reference
%     (ndi.daq.reader.mfdaq adds its start) gives the v1 clock time back.
%     REPORT.written_files lists, per converted archive (parallel to
%     changed_groups), the store paths of the files written for it, so a
%     caller that reverts the group can delete them.
%
%     Each converted group also carries a channel's time channel: Decided
%     by Jess Haley, 2026-11-17 [time channel is a per-channel covariate]:
%     "a covariate along the channel dimension of the channel group's body,
%     variable "time channel" (EMPTY:0000374), one unitless number per
%     channel, NaN and dangling values carried exactly" (the 5th covariate;
%     counted `time_channel_covariates`).
%
%     A converted group whose v1 channel names are not all the standard
%     `<prefix><number>` (the name NDI's readers give a channel) also
%     carries its names: Decided by Jess Haley, 2026-11-17 [channel name is
%     an identifier]: "a channel's v1 name is a covariate along the channel
%     dimension of its channel group's body, variable NCIT:C25364
%     "Identifier", one text value per channel" (the 6th covariate, every
%     channel's v1 name; written only where a name differs from the
%     standard form, as [channel list rows get v2 homes] says). Counted:
%     `channel_names_seen` (the rows of the converted groups),
%     `channel_names_nonstandard`, `channel_name_covariates` (groups given
%     the covariate) and `channel_names_written` (names in them).
%
%     `channel_list.bin` is REMOVED only when the readers' own rebuild
%     (ndi.vintage.ingestedChannelList, from the converted bodies as JSON
%     gives them back and the unpacked event channels) is the file's list
%     row for row ([channel list rows get v2 homes], Jess Haley, 2026-11-17:
%     "The file is removed only when the round trip rebuilds it exactly;
%     otherwise it is kept and counted"): counted `channel_list_rebuilt_exactly`,
%     else `channel_list_kept` with `first_channel_list_kept_reason`. The
%     event and marker rows' sample rate, offset, scale and time channel are
%     rebuilt as NDI's defaults (Jess Haley, 2026-11-18 [event row defaults
%     are notation]: "a channel list whose event or marker rows differ from
%     the defaults ... is kept whole as v1"). A time channel's own row is
%     rebuilt from the groups it times (Jess Haley, 2026-11-19 [time channel
%     row is notation]: "number the time group's, sample rate the group's,
%     offset 0, scale 1, name the standard prefix and number; the file is
%     removed only when the rebuild matches exactly, else it is kept whole as
%     v1 and counted"; ndi.vintage.ingestedChannelList says how), counted
%     `time_rows_seen` (the v1 time rows of converted archives),
%     `time_rows_rebuilt` (of them, rebuilt exactly) and
%     `channel_list_kept_time_row` (lists kept where a time row is not
%     rebuilt exactly). A non-standard event, marker or text channel name
%     has no v2 home yet, so a list holding one is kept.
%
%     `evmktx_group<g>_seg.nbf_#` (events): UNPACKED, one observation per
%     event, marker or text channel, and its body REMOVED, when every check
%     of unpackEvents (below) passes; else it stays the opaque_body it is,
%     counted by reason (`event_archives_seen`, `event_archives_unpacked`,
%     `event_archives_kept`, `event_kept_<reason>`, `event_channels_seen`,
%     `event_channels_unpacked`, `text_channels_seen`,
%     `text_channels_unpacked`, `event_bodies_removed`,
%     `event_bodies_left`). Decided by Jess Haley, 2026-11-17 [event
%     channels are time-valued observations], [event channel variable
%     terms], [event channel observes its wired device], [unpacked event
%     bodies are uncompressed], [unpacked events file is removed]; and
%     2026-11-19 [text channel entries are a JSON array].
%
%     MEMBER NAMES. Decided by Jess Haley, 2026-11-17 [migrated body members
%     renamed]: a converted group's members named `<type>_group<g>_seg.nbf_<n>`
%     are renamed `body_data_<n-1>`. Pass 1 already writes the schema's
%     names, so this counts them (`members_seen`, `members_renamed`,
%     `members_schema_named`, `members_not_renamed`).
%
%     OWNERS. The bodies keep the owners pass 1 gave them: by [non-specimen
%     channel groups get their own owner] (Jess Haley, 2026-11-17) a digital
%     group's `logical` observation, an auxiliary group's voltage
%     observation and an analog output group's manipulation or observation
%     are DID-matlab's (did2.convert.resolveEpochProbemap); NDI's readers
%     find a body through any of them (ndi.vintage.ingestedArchive).
%
%   THE SCALE'S UNIT. Decided by Jess Haley, 2026-11-17 [scale carries the
%   reader's unit] (did-schema did_v2_go_forward_class_audit.md): "the
%   per-channel offset covariate (AFO:AFQ_0000202) has no unit (it is in raw
%   counts); the per-channel scale covariate (NCIT:C70774) has the canonical
%   unit (volt for a voltage output) with the reader's output unit as
%   `source_unit` (e.g. microvolt for the Intan amplifier) where NDI's reader
%   for that system defines it; where it does not, the scale has no unit and
%   the run's report lists the gap." Amended by [digital scale is unitless]
%   (Jess Haley, 2026-11-17): "the scale of a `di` or `do` group has no unit
%   and is not a gap" (counted `scale_unitless_digital`). NDI reads value = (raw + offset) *
%   scale (ndi.daq.reader.mfdaq/underlying_datatype), so the scale is in the
%   reader's output unit per count. The reader is the v1 archive's
%   `daqreader_id` document among V1BODIES (`daqreader.ndi_daqreader_class`;
%   for ndi.daq.reader.mfdaq.ndr, `daqreader_ndr.ndr_reader_string`). Where
%   READERUNIT below names the output unit, the scale is written
%       quantity.value         the v1 scale converted to volts per count
%       quantity.source_value  the v1 scale, verbatim
%       unit                   om:volt
%       source_unit            the reader's output unit (om:microvolt ...)
%   and counted `scale_with_unit`; elsewhere the scale is written as before
%   (the v1 scale, no unit), counted `scale_without_unit`, and the body's
%   field `data.covariates(4).unit` is listed in REPORT.scale_gaps (parallel
%   to changed_groups: a struct array {document_id, class, field, reason}
%   per converted archive). The caller lists each gap of a group it keeps in
%   the run's migration report (did2.convert.migrationReport('gap', ...)),
%   so a reverted group lists none. A reader of the body that needs NDI's
%   own scale (ndi.vintage) reads `source_value` when it is there.
%
%   NOT HERE YET. The `compression` block ([ingested compression settings]:
%   NDI's compressor as the term, the stored integer format and bit size as
%   parameters). did-schema now declares `data_body.compression` as a
%   {term, parameters} block, but the compressor terms and the two parameter
%   variables are not registered (did-schema docs/V2_PLAN.md G92, parked
%   2026-11-03), and neither the v1 channel list nor the v1 archive document
%   states the stored integer format or bit size: only NDI-compress's own
%   header in each segment does. Until then the body keeps pass 1's
%   `compression`. The data file names stay as pass 1 wrote them.
%
%   WHERE THE BYTES ARE, as ndi.migrate.internal.epochSeriesBodies looks:
%   <NDIDIR>/files/<uid>, then the recorded location when it is a local
%   file. Every member of every series the archive converts must be here;
%   otherwise the archive is left (`bytes_not_here`). A document-only corpus
%   has no bytes: nothing changes.
%
%   REPORT.changed_groups lists, per archive converted, the ids of every
%   body replaced or removed for it; the caller re-validates each group and
%   reverts a group that does not come back clean. Apart from the rebased
%   time files above, this step writes no file.
%
%   See also did2.convert.resolveEpochProbemap,
%            ndi.migrate.internal.epochSeriesBodies,
%            ndi.file.type.mfdaq_epoch_channel, ndi.daq.reader.mfdaq.

arguments
    structs cell
    ndiDir (1,:) char
    v1Bodies cell = {}
end

report = struct( ...
    'documents_inspected',        numel(structs), ...
    'archives_seen',              0, ...
    'archives_converted',         0, ...
    'group_bodies_seen',          0, ...
    'group_bodies_described',     0, ...
    'time_bodies_removed',        0, ...
    'channel_list_removed',       0, ...
    'channel_list_kept',          0, ...
    'event_bodies_left',          0, ...
    'bytes_not_here',             0, ...
    'channel_list_missing',       0, ...
    'channel_list_unreadable',    0, ...
    'v1_archive_not_found',       0, ...
    'time_not_evenly_spaced',     0, ...
    'uneven_time_converted',      0, ...
    'uneven_time_rebased',        0, ...
    'uneven_time_values',         0, ...
    'uneven_time_mismatch_kept',  0, ...
    'uneven_time_unpaired_kept',  0, ...
    'first_uneven_time_kept_reason', '', ...
    'unconvertible',              0, ...
    'first_unconvertible_reason', '', ...
    'scale_with_unit',            0, ...
    'scale_without_unit',         0, ...
    'scale_unitless_digital',     0, ...
    'time_channel_covariates',    0, ...
    'channel_names_seen',         0, ...
    'channel_names_nonstandard',  0, ...
    'channel_name_covariates',    0, ...
    'channel_names_written',      0, ...
    'members_seen',               0, ...
    'members_renamed',            0, ...
    'members_schema_named',       0, ...
    'members_not_renamed',        0, ...
    'channel_list_rebuilt_exactly', 0, ...
    'first_channel_list_kept_reason', '', ...
    'time_rows_seen',             0, ...
    'time_rows_rebuilt',          0, ...
    'channel_list_kept_time_row', 0, ...
    'event_archives_seen',        0, ...
    'event_archives_unpacked',    0, ...
    'event_archives_kept',        0, ...
    'event_kept_text_channel',    0, ...
    'event_kept_marker_columns',  0, ...
    'event_kept_unwired',         0, ...
    'event_kept_empty_channel',   0, ...
    'event_kept_not_exact',       0, ...
    'event_kept_other',           0, ...
    'first_event_kept_reason',    '', ...
    'event_channels_seen',        0, ...
    'event_channels_unpacked',    0, ...
    'text_channels_seen',         0, ...
    'text_channels_unpacked',     0, ...
    'event_bodies_removed',       0, ...
    'uneven_time_kept',           {{}}, ...
    'scale_gaps',                 {{}}, ...
    'changed_groups',             {{}}, ...
    'written_files',              {{}}, ...
    'changed_ids',                {{}}, ...
    'added_ids',                  {{}});
removed = {};
storeDir = fullfile(ndiDir, 'files');

% ---- the pass-1 archive bodies, grouped by archive (same owners, session
% and epoch note) ---------------------------------------------------------
groupKeys = {};
groupMembers = {};
for k = 1:numel(structs)
    b = structs{k};
    if ~strcmp(className(b), 'opaque_body'); continue; end
    fn = bodyFilename(b);
    if isempty(seriesKind(fn)); continue; end
    key = archiveKeyOf(b);
    i = find(strcmp(groupKeys, key), 1);
    if isempty(i)
        groupKeys{end+1} = key; %#ok<AGROW>
        groupMembers{end+1} = k; %#ok<AGROW>
    else
        groupMembers{i}(end+1) = k;
    end
end
if isempty(groupKeys); return; end

archives = [];   % decoded lazily: only when some archive has its bytes here
readers = [];    % the v1 daqreader documents, decoded with the archives

for a = 1:numel(groupKeys)
    idx = groupMembers{a};
    kinds = cellfun(@(k) seriesKind(bodyFilename(structs{k})), num2cell(idx), ...
        'UniformOutput', false);
    if ~any(ismember(kinds, {'group', 'time'})); continue; end
    report.archives_seen = report.archives_seen + 1;
    report.group_bodies_seen = report.group_bodies_seen + sum(strcmp(kinds, 'group'));
    report.event_bodies_left = report.event_bodies_left + sum(strcmp(kinds, 'event'));

    clIdx = idx(strcmp(kinds, 'channel_list'));
    if numel(clIdx) ~= 1
        report.channel_list_missing = report.channel_list_missing + 1;
        continue;
    end
    clPath = memberPaths(structs{clIdx}, storeDir);
    if isempty(clPath)
        report.bytes_not_here = report.bytes_not_here + 1;
        continue;
    end
    try
        ci = ndi.file.type.mfdaq_epoch_channel(clPath{1}).channel_information;
    catch
        report.channel_list_unreadable = report.channel_list_unreadable + 1;
        continue;
    end

    if isempty(archives)
        archives = v1ArchivesByUid(v1Bodies);
        readers = v1ReadersById(v1Bodies);
    end
    arch = archiveOf(structs(idx), archives);
    if isempty(arch)
        report.v1_archive_not_found = report.v1_archive_not_found + 1;
        continue;
    end

    try
        [made, gone, why, added, uneven, written, info] = convertArchive(structs, idx, kinds, clIdx, ci, arch, ...
            readerOf(arch, readers), storeDir);
    catch err
        made = {}; gone = {}; added = {}; uneven = false; written = {}; info = [];
        why = sprintf('%s: %s', err.identifier, err.message);
    end
    if uneven
        report.time_not_evenly_spaced = report.time_not_evenly_spaced + 1;
    end
    if strcmp(why, 'bytes_not_here')
        report.bytes_not_here = report.bytes_not_here + 1;
        continue;
    elseif ~isempty(why)
        report.unconvertible = report.unconvertible + 1;
        if isempty(report.first_unconvertible_reason)
            report.first_unconvertible_reason = why;
        end
        % [uneven time groups and mismatches] (Jess Haley, 2026-11-19): a
        % time channel whose sample count differs from the data it times is
        % malformed: the archive is kept as v1, counted and reported
        if isstruct(info) && isfield(info, 'timeKept') && ~isempty(info.timeKept)
            f = ['uneven_time_' info.timeKept '_kept'];
            report.(f) = report.(f) + 1;
            if isempty(report.first_uneven_time_kept_reason)
                report.first_uneven_time_kept_reason = why;
            end
            report.uneven_time_kept{end+1} = struct('kind', info.timeKept, ...
                'archive_id', baseId(arch), 'group_body_id', info.timeKeptBody, ...
                'time_body_id', info.timeKeptTimeBody, 'reason', why);
        end
        continue;
    end

    ids = {};
    gaps = struct('document_id', {}, 'class', {}, 'field', {}, 'reason', {});
    for m = 1:numel(made)
        structs{made{m}.k} = made{m}.body;
        ids{end+1} = baseId(made{m}.body); %#ok<AGROW>
        if ~isfield(made{m}, 'scaleGap'); continue; end   % the time value's body
        if made{m}.scaleUnitless
            % [digital scale is unitless]: no unit and not a gap
            report.scale_unitless_digital = report.scale_unitless_digital + 1;
        elseif isempty(made{m}.scaleGap)
            report.scale_with_unit = report.scale_with_unit + 1;
        else
            report.scale_without_unit = report.scale_without_unit + 1;
            gaps(end+1) = struct('document_id', baseId(made{m}.body), ...
                'class', 'sampled_body', 'field', made{m}.scaleField, ...
                'reason', made{m}.scaleGap); %#ok<AGROW>
        end
    end
    report.scale_gaps{end+1} = gaps;
    for m = 1:numel(added)
        structs{end+1} = added{m}; %#ok<AGROW>
        ids{end+1} = baseId(added{m}); %#ok<AGROW>
        report.added_ids{end+1} = baseId(added{m});
    end
    if uneven
        report.uneven_time_converted = report.uneven_time_converted + 1;
        report.uneven_time_values = report.uneven_time_values + info.timeValues;
        if info.rebased
            report.uneven_time_rebased = report.uneven_time_rebased + 1;
        end
    end
    for g = 1:numel(gone)
        ids{end+1} = gone{g}; %#ok<AGROW>
        removed{end+1} = gone{g}; %#ok<AGROW>
        if strcmp(gone{g}, baseId(structs{clIdx}))
            report.channel_list_removed = report.channel_list_removed + 1;
        elseif any(strcmp(gone{g}, info.eventBodyIds))
            report.event_bodies_removed = report.event_bodies_removed + 1;
        else
            report.time_bodies_removed = report.time_bodies_removed + 1;
        end
    end
    if ~any(strcmp(gone, baseId(structs{clIdx})))
        report.channel_list_kept = report.channel_list_kept + 1;
        if isempty(report.first_channel_list_kept_reason)
            report.first_channel_list_kept_reason = info.channelListWhy;
        end
    else
        report.channel_list_rebuilt_exactly = report.channel_list_rebuilt_exactly + 1;
    end
    % [time channel row is notation] (Jess Haley, 2026-11-19)
    report.time_rows_seen = report.time_rows_seen + info.timeRows(1);
    report.time_rows_rebuilt = report.time_rows_rebuilt + info.timeRows(2);
    if info.timeRowKept
        report.channel_list_kept_time_row = report.channel_list_kept_time_row + 1;
    end
    report.time_channel_covariates = report.time_channel_covariates + info.timeChannelCovariates;
    report.channel_names_seen = report.channel_names_seen + info.names(1);
    report.channel_names_nonstandard = report.channel_names_nonstandard + info.names(2);
    report.channel_name_covariates = report.channel_name_covariates + info.names(3);
    report.channel_names_written = report.channel_names_written + info.names(4);
    report.members_seen = report.members_seen + info.members(1);
    report.members_renamed = report.members_renamed + info.members(2);
    report.members_schema_named = report.members_schema_named + info.members(3);
    report.members_not_renamed = report.members_not_renamed + info.members(4);
    ev = info.events;
    if ev.present
        report.event_archives_seen = report.event_archives_seen + 1;
        report.event_channels_seen = report.event_channels_seen + ev.channels;
        report.text_channels_seen = report.text_channels_seen + ev.textChannels;
        if ev.unpacked
            report.event_archives_unpacked = report.event_archives_unpacked + 1;
            report.event_channels_unpacked = report.event_channels_unpacked + ev.channels;
            report.text_channels_unpacked = report.text_channels_unpacked + ev.textChannels;
            report.event_bodies_left = report.event_bodies_left - 1;
        else
            report.event_archives_kept = report.event_archives_kept + 1;
            f = ['event_kept_' ev.kind];
            report.(f) = report.(f) + 1;
            if isempty(report.first_event_kept_reason)
                report.first_event_kept_reason = ev.why;
            end
        end
    end
    report.archives_converted = report.archives_converted + 1;
    report.group_bodies_described = report.group_bodies_described + numel(made) - numel(added);
    report.changed_groups{end+1} = ids;
    report.written_files{end+1} = written;
    report.changed_ids = [report.changed_ids, ids];
end
end

% =====================================================================

function [made, gone, why, added, uneven, written, info] = convertArchive(structs, idx, kinds, clIdx, ci, arch, reader, storeDir)
%CONVERTARCHIVE The sampled bodies of one archive, or why it is left. ADDED
%   are the documents made for it (the `time` value of each unevenly spaced
%   time group); UNEVEN is true when a time group is not evenly spaced.
%   WRITTEN are the store paths of the files written for it (the rebased
%   time segments when the epoch does not start at 0, the unpacked event
%   channels' files); written last, only once every check has passed.
%   READER is the archive's v1 daqreader (readerOf); each channel group's
%   entry of MADE says, in `scaleGap`, why its scale has no unit ('' when it
%   has one) and, in `scaleField`, the field that gap names; `scaleUnitless`
%   is true for a digital group, whose scale has no unit and is no gap
%   ([digital scale is unitless]). INFO says what else was done:
%   eventBodyIds (the `evmktx` bodies removed), channelListWhy (why
%   channel_list.bin is kept, '' when removed), timeChannelCovariates,
%   members ([seen renamed schema-named not-renamed]), names ([seen
%   non-standard covariates written], [channel name is an identifier]),
%   events (unpackEvents), timeValues (keyed time values written), rebased
%   (some were rewritten from the epoch's start), timeRows ([v1 time rows,
%   of them rebuilt exactly]) and timeRowKept (channel_list.bin kept because
%   a time row is not rebuilt exactly); when the archive is left because of
%   its uneven time ([uneven time groups and mismatches]), timeKept is
%   'mismatch' or 'unpaired' and timeKeptBody / timeKeptTimeBody name the
%   channel group and the time body.
made = {};
gone = {};
why = '';
added = {};
uneven = false;
written = {};
info = struct('eventBodyIds', {{}}, 'channelListWhy', '', 'timeChannelCovariates', 0, ...
    'members', [0 0 0 0], 'names', [0 0 0 0], 'events', struct('present', false, 'unpacked', false, ...
    'channels', 0, 'textChannels', 0, 'kind', '', 'why', ''), 'timeValues', 0, 'rebased', false, ...
    'timeRows', [0 0], 'timeRowKept', false, 'timeKept', '', 'timeKeptBody', '', ...
    'timeKeptTimeBody', '');
% [migrated body members renamed]: the members of the channel and time
% groups, by the schema's names, before anything reads them
for j = 1:numel(idx)
    if ~any(strcmp(kinds{j}, {'group', 'time'})); continue; end
    [structs{idx(j)}, counts] = renameMembers(structs{idx(j)});
    info.members = info.members + counts;
end
[types, abbrev] = ndi.daq.reader.mfdaq.channel_types();
ciType = cellfun(@char, {ci.type}, 'UniformOutput', false);
ciGroup = double([ci.group]);
params = struct();
if isfield(arch, 'daqreader_mfdaq_epochdata_ingested') ...
        && isfield(arch.daqreader_mfdaq_epochdata_ingested, 'parameters')
    params = arch.daqreader_mfdaq_epochdata_ingested.parameters;
end
t0 = epochStart(arch);

% the time groups first: each evenly spaced from the epoch's start is
% removed; each that is not becomes the body of its own keyed `time` value
% ([uneven time groups and mismatches], Jess Haley, 2026-11-19: "one `time`
% value per time group")
timeJ = find(strcmp(kinds, 'time'));
keyed = struct('k', {}, 'number', {}, 'n', {}, 'seg', {}, 'id', {}, 'tsegs', {});
evenNumbers = [];   % the time channels of the evenly spaced (removed) groups
for j = timeJ(:)'
    b = structs{idx(j)};
    [~, g] = prefixAndGroup(bodyFilename(b));
    rows = find(strcmp(ciType, 'time') & ciGroup == g);
    if isempty(rows); why = sprintf('no channel_list row for %s', bodyFilename(b)); return; end
    paths = memberPaths(b, storeDir);
    if isempty(paths); why = 'bytes_not_here'; return; end
    if ~isfinite(t0); why = 'the v1 archive names no epoch start (t0_t1)'; return; end
    tsegs = cell(1, numel(paths));
    for m = 1:numel(paths)
        tsegs{m} = expandSegment(paths{m}, 'time');
    end
    t = vertcat(tsegs{:});
    if size(t, 2) ~= numel(rows)
        why = sprintf('%s holds %d column(s), the channel list %d', ...
            bodyFilename(b), size(t, 2), numel(rows));
        return;
    end
    even = true;
    for r = 1:numel(rows)
        sr = double(ci(rows(r)).sample_rate);
        if ~(isfinite(sr) && sr > 0); even = false; break; end
        ideal = t0 + (0:size(t, 1)-1)' / sr;
        if any(abs(double(t(:, r)) - ideal) > max(1e-9, 1e-6 / sr))
            even = false;
            break;
        end
    end
    if even
        gone{end+1} = baseId(b); %#ok<AGROW>
        evenNumbers = [evenNumbers, double([ci(rows).number])]; %#ok<AGROW>
        continue;
    end
    % [uneven time is a keyed time value]
    uneven = true;
    if ~isscalar(rows)
        why = sprintf(['the time channels of %s are not evenly spaced, and the group holds ' ...
            '%d time channels: a keyed time value is written for a time group of one time ' ...
            'channel only'], bodyFilename(b), numel(rows));
        return;
    end
    seg = paramOf(params, 'sample_analog_segment');
    if ~isfinite(seg); seg = size(tsegs{1}, 1); end
    % the keyed time value's id is derived from the time body it is minted
    % for, not random ([migration reliability practices] (b), Jess Haley,
    % 2026-10-26)
    keyed(end+1) = struct('k', idx(j), 'number', double(ci(rows).number), ...
        'n', size(t, 1), 'seg', seg, ...
        'id', did2.convert.mintId('keyed time value', baseId(b)), ...
        'tsegs', {tsegs}); %#ok<AGROW>
end
nTimeRows = sum(strcmp(ciType, 'time'));

for j = 1:numel(idx)
    if ~strcmp(kinds{j}, 'group'); continue; end
    k = idx(j);
    b = structs{k};
    fn = bodyFilename(b);
    [prefix, g] = prefixAndGroup(fn);
    switch prefix
        case 'ai', want = {'analog_in'};
        case 'ao', want = {'analog_out'};
        case 'ax', want = {'auxiliary_in'};
        case 'di', want = {'digital_in', 'digital_out'};  % v1 mfdaq writes digital_out as di
        case 'do', want = {'digital_out'};
    end
    rows = find(ismember(ciType, want) & ciGroup == g);
    if isempty(rows); why = sprintf('no channel_list row for %s', fn); return; end
    if numel(unique(ciType(rows))) ~= 1
        why = sprintf('%s mixes channel types %s', fn, strjoin(unique(ciType(rows)), ', '));
        return;
    end
    type = ciType{rows(1)};
    sr = unique(double([ci(rows).sample_rate]));
    if ~isscalar(sr) || ~isfinite(sr) || sr <= 0
        why = sprintf('%s has no single sample rate', fn);
        return;
    end
    dataclass = char(ci(rows(1)).dataclass);
    switch dataclass
        case 'ephys',   seg = paramOf(params, 'sample_analog_segment');
        case 'digital', seg = paramOf(params, 'sample_digital_segment');
        otherwise
            why = sprintf('%s has data class %s', fn, dataclass);
            return;
    end
    paths = memberPaths(b, storeDir);
    if isempty(paths); why = 'bytes_not_here'; return; end
    last = expandSegment(paths{end}, dataclass);
    if ~isfinite(seg)
        if isscalar(paths); seg = size(last, 1);
        else; seg = size(expandSegment(paths{1}, dataclass), 1); end
    end
    if size(last, 2) ~= numel(rows) || size(last, 1) > seg
        why = sprintf('%s: last segment %dx%d, %d channel(s), segment length %d', ...
            fn, size(last, 1), size(last, 2), numel(rows), seg);
        return;
    end
    n = (numel(paths) - 1) * seg + size(last, 1);

    timeId = '';
    if ~isempty(keyed)
        % [uneven time groups and mismatches] (Jess Haley, 2026-11-19): "each
        % channel group keyed to the time group it uses, as the channel list
        % pairs them"
        [kk, pairWhy] = pairedTime(ci, rows, keyed, evenNumbers, nTimeRows);
        if ~isempty(pairWhy)
            why = sprintf('%s: %s', fn, pairWhy);
            info.timeKept = 'unpaired';
            info.timeKeptBody = baseId(b);
            return;
        end
        if kk > 0
            if n ~= keyed(kk).n
                % "a time channel whose sample count differs from the data it
                % times is malformed: the archive is kept as v1, counted"
                why = sprintf(['%s holds %d sample(s), its time channel t%d (%s) %d: a time ' ...
                    'channel whose sample count differs from the data it times is malformed, ' ...
                    'so the archive is kept as v1'], fn, n, keyed(kk).number, ...
                    bodyFilename(structs{keyed(kk).k}), keyed(kk).n);
                info.timeKept = 'mismatch';
                info.timeKeptBody = baseId(b);
                info.timeKeptTimeBody = baseId(structs{keyed(kk).k});
                return;
            end
            timeId = keyed(kk).id;
        end
    end
    [body, scaleGap, scaleField, nameCounts] = sampledFromOpaque(b, rows, ci, type, types, abbrev, ...
        sr, n, seg, timeId, reader);
    info.names = info.names + nameCounts;
    made{end+1} = struct('k', k, 'body', body, 'scaleGap', scaleGap, ...
        'scaleField', scaleField, 'scaleUnitless', strcmp(dataclass, 'digital')); %#ok<AGROW>
    info.timeChannelCovariates = info.timeChannelCovariates + 1;
end
if isempty(made); why = 'no channel group to convert'; return; end
groupBodies = cellfun(@(m) m.body, made, 'UniformOutput', false);

% [event channels are time-valued observations]: the events file, unpacked
% when every check passes; else left as it is (counted)
[ev, evDocs, evWritten, evRows] = unpackEvents(structs, idx, kinds, ci, t0, storeDir);
info.events = ev;

for q = 1:numel(keyed)
    try
        [value, tbody, w] = keyedTime(structs{keyed(q).k}, keyed(q).id, keyed(q).n, ...
            keyed(q).seg, t0, keyed(q).tsegs, storeDir);
    catch err
        cellfun(@deleteIfThere, [written, evWritten]);
        rethrow(err);
    end
    written = [written, w]; %#ok<AGROW>
    added{end+1} = value; %#ok<AGROW>
    made{end+1} = struct('k', keyed(q).k, 'body', tbody); %#ok<AGROW>
end
info.timeValues = numel(keyed);
info.rebased = ~isempty(written);
if ev.unpacked
    added = [added, evDocs];
    written = [written, evWritten];
    info.eventBodyIds = {baseId(structs{idx(strcmp(kinds, 'event'))})};
    gone{end+1} = info.eventBodyIds{1};
end

% [channel list rows get v2 homes]: "The file is removed only when the round
% trip rebuilds it exactly; otherwise it is kept and counted." The rebuild is
% the readers' own (ndi.vintage.ingestedChannelList), from the bodies as the
% database gives them back (JSON); it rebuilds a time channel's own row from
% the groups it times ([time channel row is notation], Jess Haley, 2026-11-19)
rebuilt = ndi.vintage.ingestedChannelList(cellfun(@(b) jsondecode(jsonencode(b)), ...
    groupBodies, 'UniformOutput', false), evRows);
info.channelListWhy = channelListDifference(rebuilt, ci);
[info.timeRows, info.timeRowKept] = timeRowsCompared(rebuilt, ci, info.channelListWhy);
if isempty(info.channelListWhy)
    gone{end+1} = baseId(structs{clIdx});
end
end

function [kk, why] = pairedTime(ci, rows, keyed, evenNumbers, nTimeRows)
% The keyed time value a channel group's ROWS key to: KK its index in KEYED,
% 0 when their time channel's group is evenly spaced (the group's own time
% covariate), or WHY it cannot be paired. The channel list pairs them: every
% row's v1 time_channel names one time channel. When it names none of the
% archive's (NaN, several, or one with no row) and the archive has exactly
% one time channel, the group keys to that one, as the single-group path
% did (NDI-matlab #1226).
kk = 0;
why = '';
tc = NaN(1, numel(rows));
for r = 1:numel(rows)
    v = double(ci(rows(r)).time_channel);
    if isscalar(v); tc(r) = v; end
end
u = unique(tc(isfinite(tc)));
if all(isfinite(tc)) && isscalar(u)
    i = find([keyed.number] == u, 1);
    if ~isempty(i); kk = i; return; end
    if any(evenNumbers == u); return; end
end
if nTimeRows == 1 && isscalar(keyed)
    kk = 1;
    return;
end
shown = strjoin(arrayfun(@(x) sprintf('%g', x), unique(tc), 'UniformOutput', false), ', ');
why = sprintf(['its channels name time channel(s) %s, not one time channel of the archive ' ...
    '(%d time channel(s), %d of them not evenly spaced): the channel list does not pair it ' ...
    'with a time group'], shown, nTimeRows, numel(keyed));
end

function [counts, kept] = timeRowsCompared(rebuilt, ci, listWhy)
% COUNTS [v1 time rows, of them rebuilt exactly]; KEPT true when the list is
% kept and a time row is why (a v1 time row not rebuilt exactly, or a time
% row rebuilt that the v1 list does not hold)
isT = strcmp(cellfun(@char, {ci.type}, 'UniformOutput', false), 'time');
rT = false(1, numel(rebuilt));
if ~isempty(rebuilt)
    rT = strcmp(cellfun(@char, {rebuilt.type}, 'UniformOutput', false), 'time');
end
v1 = ci(isT);
rb = rebuilt(rT);
same = 0;
for r = 1:numel(v1)
    for q = 1:numel(rb)
        if isempty(channelListDifference(rb(q), v1(r))); same = same + 1; break; end
    end
end
counts = [numel(v1), same];
kept = ~isempty(listWhy) && (same < numel(v1) || numel(rb) ~= numel(v1));
end

function why = channelListDifference(rebuilt, ci)
% '' when REBUILT is the v1 channel list CI, row for row; else the first
% difference
why = '';
f = {'name', 'type', 'time_channel', 'sample_rate', 'offset', 'scale', 'number', ...
    'group', 'dataclass'};
if numel(rebuilt) ~= numel(ci)
    a = cellfun(@char, {rebuilt.name}, 'UniformOutput', false);
    b = cellfun(@char, {ci.name}, 'UniformOutput', false);
    why = sprintf(['the v2 documents rebuild %d channel_list.bin row(s) of %d (not rebuilt: ' ...
        '%s; rebuilt but not in the list: %s; a non-standard event, marker or text name, an ' ...
        'events file left packed, or a time channel a group names that the list does not ' ...
        'hold)'], numel(rebuilt), numel(ci), listOrNone(setdiff(b, a)), listOrNone(setdiff(a, b)));
    return;
end
for r = 1:numel(ci)
    for i = 1:numel(f)
        a = rebuilt(r).(f{i});
        b = ci(r).(f{i});
        if ischar(a) || ischar(b) || isstring(b)
            same = strcmp(char(a), char(b));
        else
            same = isequaln(double(a), double(b));
        end
        if ~same
            why = sprintf('channel_list.bin row %d (%s): its %s is not rebuilt exactly', ...
                r, char(ci(r).name), f{i});
            return;
        end
    end
end
end

function s = listOrNone(c)
if isempty(c); s = 'none'; else; s = strjoin(c, ', '); end
end

function [b, counts] = renameMembers(b)
% [migrated body members renamed] (Jess Haley, 2026-11-17): "NDI's second
% pass renames a converted channel group's file members from
% `<type>_group<g>_seg.nbf_<n>` to `body_data_0`, `body_data_1`, ... in
% segment order; the bytes and the store are unchanged; a name that does not
% fit NDI's pattern is not renamed, and the run counts it." Pass 1
% (did2.convert.resolveEpochProbemap archiveBodies) already names them so;
% COUNTS is [seen renamed already-schema-named not-renamed]
counts = [0 0 0 0];
if ~isfield(b, 'files') || ~isstruct(b.files) || ~isfield(b.files, 'file_info')
    return;
end
fi = b.files.file_info;
wasStruct = isstruct(fi);
if wasStruct; fi = num2cell(fi); end
stem = regexprep(bodyFilename(b), '#$', '');
for m = 1:numel(fi)
    if ~isstruct(fi{m}) || ~isfield(fi{m}, 'name'); continue; end
    counts(1) = counts(1) + 1;
    nm = char(fi{m}.name);
    if ~isempty(regexp(nm, '^body_data_\d+$', 'once'))
        counts(3) = counts(3) + 1;
        continue;
    end
    tok = regexp(nm, ['^' regexptranslate('escape', stem) '(\d+)$'], 'tokens', 'once');
    if isempty(tok) || str2double(tok{1}) < 1
        counts(4) = counts(4) + 1;
        continue;
    end
    fi{m}.name = sprintf('body_data_%d', str2double(tok{1}) - 1);
    counts(2) = counts(2) + 1;
end
if wasStruct; fi = [fi{:}]; end
b.files.file_info = fi;
if counts(2) > 0 && isfield(b.files, 'file_list')
    names = cellfun(@(x) char(x.name), num2cell(b.files.file_info), 'UniformOutput', false);
    b.files.file_list = names;
end
end

function [value, body, written] = keyedTime(tb, valueId, n, seg, t0, tsegs, storeDir)
% [uneven time is a keyed time value]: the standalone `time` value
% (data_body true; no time reference) and the time group's body as its
% sampled_body, one time dimension, id, format and compression kept. Its
% files are pass 1's when the epoch starts at 0 (T0); otherwise ([uneven time
% rewritten from the epoch start]) each v1 segment TSEGS{m} is rewritten as
% TSEGS{m} - T0 into a new store file, WRITTEN its paths
written = {};
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
sid = char(did2.schema.cache.sessionIdOf(tb));
ts = '';
if isfield(tb.base, 'creation_timestamp'); ts = char(tb.base.creation_timestamp); end
tsArg = {};
if ~isempty(ts); tsArg = {'CreationTimestamp', ts}; end
value = did2.build.document('time', struct('data_body', true), ...
    'Id', valueId, 'SessionId', sid, 'Validate', false, tsArg{:});
db = tb.data_body;
timeTerm = struct('node', 'om:Time', 'name', 'time');
args = {'Id', baseId(tb), 'SessionId', sid, 'Validate', false, ...
    'Fields', struct('filename', bodyFilename(tb)), ...
    'Notes', sprintf(['%s The NDI second pass read it as the body of the recording''s ' ...
        'time value (%d unevenly spaced sample(s), seconds from the epoch''s start); ' ...
        'each channel group''s time is a key to it.%s'], strtrim(ndi.v2.notesOf(db)), n, ...
        rebasedNote(t0)), ...
    tsArg{:}};
if isfield(db, 'format') && isstruct(db.format) && isfield(db.format, 'node') ...
        && ~isempty(db.format.node)
    args = [args, {'Format', db.format}];
end
if isfield(db, 'compression') && ~isempty(db.compression)
    args = [args, {'Compression', db.compression}];
end
body = did2.build.sampledBody(baseId(value), ...
    did2.build.dimension(timeTerm, n, 'Chunk', seg), args{:});
body.files = tb.files;
if t0 ~= 0
    [body.files, written] = rebasedTimeFiles(tb.files, tsegs, t0, storeDir, baseId(tb));
end
end

function s = rebasedNote(t0)
s = '';
if t0 ~= 0
    s = sprintf([' Its v1 times were on the epoch''s clock, from t0 = %.17g s; they were ' ...
        'rewritten as t - t0 into new files (the epoch''s start is on the recording''s ' ...
        'time references).'], t0);
end
end

function [files, written] = rebasedTimeFiles(files, tsegs, t0, storeDir, sourceId)
% [uneven time rewritten from the epoch start]: v1 segment m (member
% body_data_<m-1>), rewritten as t - t0, compressed as the v1 ingest
% compressed it (ndi.compress.compress_time), into the store under a new uid
infos = files.file_info;
if isstruct(infos); infos = num2cell(infos); end
names = cellfun(@(f) char(f.name), infos, 'UniformOutput', false);
written = {};
out = cell(1, numel(tsegs));
try
    for m = 1:numel(tsegs)
        i = find(strcmp(names, sprintf('body_data_%d', m - 1)), 1);
        fi = infos{i};
        % the rewritten file's uid is derived from the time body and the
        % segment, not random ([migration reliability practices] (b))
        uid = char(did2.convert.mintId(sprintf('rebased time file|%d', m), ...
            sourceId));
        dest = fullfile(storeDir, uid);
        stem = ndi.file.temp_name();
        ndi.compress.compress_time(double(tsegs{m}) - t0, stem);
        movefile([stem '.nbf.tgz'], dest);
        written{end+1} = dest; %#ok<AGROW>
        loc = struct('delete_original', 0, 'uid', uid, 'location', dest, ...
            'parameters', '', 'location_type', 'file', 'ingest', 1);
        fi.locations = loc;
        out{m} = fi;
    end
catch err
    cellfun(@deleteIfThere, written);
    rethrow(err);
end
files.file_info = [out{:}];
end

function [body, scaleGap, scaleField, nameCounts] = sampledFromOpaque(b, rows, ci, type, types, abbrev, sr, n, seg, timeId, reader)
% the channel number variable is a label no registry row carries yet, as the
% other second-pass builders' labels (ndi.migrate.internal.termRegistryOff)
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
ab = abbrev{strcmp(types, type)};
[node, label] = channelTypeTerm(ab);
timeTerm = struct('node', 'om:Time', 'name', 'time');
channelTerm = struct('node', 'NCIT:C44170', 'name', 'Channel');
dims = did2.build.list( ...
    did2.build.dimension(timeTerm, n, 'Chunk', seg), ...
    did2.build.dimension(channelTerm, numel(rows)));
if isempty(timeId)
    % [evenly spaced time is a covariate]
    timeCov = did2.build.covariate(timeTerm, 0, 'Origin', 0, 'Spacing', 1 / sr, ...
        'Unit', struct('node', 'om:second-Time', 'name', 'second'));
    keyArgs = {};
else
    % [uneven time is a keyed time value]: position k of the time value
    timeCov = did2.build.covariate(timeTerm, 0, 'Key', 0);
    keyArgs = {'KeyIds', {timeId}};
end
% [scale carries the reader's unit]: the offset is in raw counts, no unit;
% the scale is in volts per count where the reader defines its output unit
scale = double([ci(rows).scale]);
[perVolt, sourceUnit, scaleGap] = readerUnit(reader, type);
if any(strcmp(type, {'digital_in', 'digital_out'}))
    % [digital scale is unitless] (Jess Haley, 2026-11-17): "the scale of a
    % `di` or `do` group has no unit and is not a gap"
    scaleGap = '';
    scaleCov = did2.build.covariate(SCALE(), 1, 'Value', scale);
elseif isempty(scaleGap)
    scaleCov = did2.build.covariate(SCALE(), 1, 'Value', scale * perVolt, ...
        'SourceValue', scale, 'Unit', VOLT(), 'SourceUnit', sourceUnit);
else
    scaleCov = did2.build.covariate(SCALE(), 1, 'Value', scale);
end
% [time channel is a per-channel covariate] (Jess Haley, 2026-11-17): "a
% covariate along the channel dimension of the channel group's body, variable
% "time channel" (EMPTY:0000374), one unitless number per channel, NaN and
% dangling values carried exactly; it is always written for a converted
% group"
tc = NaN(1, numel(rows));
for r = 1:numel(rows)
    v = double(ci(rows(r)).time_channel);
    if isscalar(v); tc(r) = v; end
end
covList = {timeCov, ...
    did2.build.covariate(CHANNEL_NUMBER(), 1, 'Count', double([ci(rows).number])), ...
    did2.build.covariate(OFFSET(), 1, 'Value', double([ci(rows).offset])), ...
    scaleCov, ...
    did2.build.covariate(TIME_CHANNEL(), 1, 'Value', tc)};
% [channel name is an identifier] (Jess Haley, 2026-11-17): "a channel's v1
% name is a covariate along the channel dimension of its channel group's
% body, variable NCIT:C25364 "Identifier", one text value per channel";
% written only on a group where some v1 name is not the standard
% `<prefix><number>` ([channel list rows get v2 homes]: "written only where
% a name differs from the standard type-and-number form"). NAMECOUNTS is
% [seen non-standard covariates written]
names = cell(1, numel(rows));
standard = false(1, numel(rows));
for r = 1:numel(rows)
    names{r} = char(ci(rows(r)).name);
    standard(r) = strcmp(names{r}, sprintf('%s%d', ab, double(ci(rows(r)).number)));
end
nameCounts = [numel(rows), sum(~standard), 0, 0];
if ~all(standard)
    covList{end+1} = did2.build.covariate(IDENTIFIER(), 1, 'Text', names);
    nameCounts(3:4) = [1, numel(rows)];
end
covs = did2.build.list(covList{:});
% the field a gap names: the scale is the 4th covariate (1-based, as a gap's
% path counts a struct-array field)
scaleField = 'data.covariates(4).unit';
conds = did2.build.condition(channelTerm, 'Term', struct('node', node, 'name', label));

db = b.data_body;
sid = char(did2.schema.cache.sessionIdOf(b));
ts = '';
if isfield(b.base, 'creation_timestamp'); ts = char(b.base.creation_timestamp); end
args = {'Covariates', covs, 'Conditions', conds, 'DatumOrder', 'F', keyArgs{:}, ...
    'Id', baseId(b), 'SessionId', sid, 'Validate', false, ...
    'Fields', struct('filename', bodyFilename(b)), ...
    'Notes', sprintf(['%s The NDI second pass read it as one sampled body ' ...
        '(channel group of %d %s channel(s), %d sample(s)); the v1 ' ...
        'channel_list.bin rows are its covariates.'], ...
        strtrim(ndi.v2.notesOf(db)), numel(rows), type, n)};
if ~isempty(ts); args = [args, {'CreationTimestamp', ts}]; end
if isfield(db, 'format') && isstruct(db.format) && isfield(db.format, 'node') ...
        && ~isempty(db.format.node)
    args = [args, {'Format', db.format}];
end
if isfield(db, 'compression') && ~isempty(db.compression)
    args = [args, {'Compression', db.compression}];
end
body = did2.build.sampledBody(edgeValues(b, 'owner_id'), dims, args{:});
body.files = b.files;
end

% ---- the events file ([event channels are time-valued observations]) ----

function [ev, docs, written, rows] = unpackEvents(structs, idx, kinds, ci, t0, storeDir)
%UNPACKEVENTS The archive's `evmktx_group<g>_seg.nbf_#` file, unpacked into one
%   observation per channel. Decided by Jess Haley, 2026-11-17 (did-schema
%   did_v2_go_forward_class_audit.md):
%
%   [event channels are time-valued observations]: "one observation per
%     channel, instrument the acquisition system, the epoch's time reference:
%     an event channel is a `time` value (the event times, seconds from the
%     epoch start, in a `sampled_body`); a marker channel is a `label` value
%     (one code per event ...) keyed to a `time` value of the event times
%     ...; the channel's name is kept in the observation's notes".
%   [event channel variable terms], amended by [event channel observes its
%     wired device]: the variable of an event channel is NCIT:C25499
%     "Event", of a marker channel NCIT:C25162 "Code"; `entity_id` "the
%     device entity wired to that channel by its `connected to` relation".
%   [unpacked event bodies are uncompressed]: "event times and numeric codes
%     as little-endian 64-bit floats, format EDAM "binary", with no
%     compression block".
%   [text channel entries are a JSON array] (Jess Haley, 2026-11-19): "an
%     unpacked text channel's times are an uncompressed array of 64-bit
%     floats, as for events ...; its entries are one uncompressed UTF-8 JSON
%     array of strings in the same order, format EDAM format_3464 "JSON"";
%     its variable is NCIT:C44272 "Annotation" ([event channel variable
%     terms]).
%   [channel list rows get v2 homes]: each records "its channel type and
%     number as a condition (e.g. "marker channel", EMPTY:0000377, count 1)".
%   [unpacked events file is removed]: its opaque_body is removed; "An
%     archive whose file the round trip cannot rebuild exactly is not
%     unpacked: it stays as today's opaque body, and the run counts it."
%
%   Written here as:
%     an event channel   observation (value kind time), variable Event,
%                        data_type float64, data_body true; its
%                        sampled_body: one time dimension (om:Time, as the
%                        keyed time value of [uneven time is a keyed time
%                        value]), n = the events, member body_data_0 = the
%                        times - t0
%     a marker channel   observation (value kind label), variable Code,
%                        data_type float64, data_body true; its sampled_body:
%                        one time dimension whose time covariate is key 0 to
%                        a standalone `time` value (data_body true, float64)
%                        whose sampled_body holds the times - t0; member
%                        body_data_0 = the codes
%     a text channel     observation (value kind text), variable Annotation,
%                        data_type utf8, data_body true; its sampled_body:
%                        one time dimension whose time covariate is key 0 to
%                        a standalone `time` value (as a marker's), format
%                        EDAM:format_3464 "JSON", no byte order (single-byte)
%                        and no compression; member body_data_0 = the
%                        entries, one UTF-8 JSON array of strings in event
%                        order (ndi.vintage.ingestedEventData reads it back)
%   each with entity_id the wired device, `acquisition_system_id` the
%   system the archive's recordings name ("instrument the acquisition
%   system": an acquisition system is not an `entity`, which `instrument_id`
%   requires, so the system is named where an interaction names its rig),
%   time_reference_id the recordings' anchors, the channel's type and number
%   as a condition, and its v1 name in the notes. New files go into the store
%   (<NDIDIR>/files/<uid>), their uids derived from the events body.
%
%   LEFT PACKED (EV.unpacked false, EV.kind and EV.why say why; the archive's
%   channel groups still convert), when:
%     text_channel     not used since [text channel entries are a JSON
%                      array] (2026-11-19): text channels are unpacked; a
%                      text channel whose entries do not come back exactly
%                      from their JSON array is `not_exact`
%     marker_columns   a marker whose events carry several numbers: the
%                      second dimension ([several marker numbers are a second
%                      dimension]) has no decided term
%     unwired          a channel (event, marker or text) no `connected to`
%                      relation of the epoch wires, or that several wire: the
%                      decision's fallback entity, the acquisition system, is
%                      not an `entity`
%     empty_channel    a channel with no event
%     not_exact        the channels read back (ndi.vintage.ingestedEventData,
%                      the reader's rule) or NDI's own round trip
%                      (ndi.compress.compress_eventmarktext, then
%                      expand_eventmarktext) differ from the file
%     other            no single file, bytes not here, no epoch start, no
%                      single acquisition system, a channel not in the
%                      channel list
%   ROWS are the {type, number} of the unpacked channels, for the channel-list
%   rebuild (ndi.vintage.ingestedChannelList); DOCS the documents made;
%   WRITTEN the store files written (only once every check has passed).
ev = struct('present', false, 'unpacked', false, 'channels', 0, 'textChannels', 0, ...
    'kind', '', 'why', '');
docs = {};
written = {};
rows = struct('type', {}, 'number', {});
j = find(strcmp(kinds, 'event'));
if isempty(j); return; end
ev.present = true;
if ~isscalar(j)
    ev = left(ev, 'other', sprintf('%d events files in one archive', numel(j)));
    return;
end
b = structs{idx(j)};
paths = memberPaths(b, storeDir);
if ~isscalar(paths)
    ev = left(ev, 'other', 'the events file''s bytes are not here (or it has several members)');
    return;
end
stem = ndi.file.temp_name();
copyfile(paths{1}, [stem '.nbf.tgz']);
c1 = onCleanup(@() deleteIfThere([stem '.nbf.tgz']));
try
    [ct, cn, T, D] = ndi.compress.expand_eventmarktext(stem);
catch err
    % e.g. a non-ASCII text entry: NDI-compress writes it as UTF-8 but reads
    % it back byte by byte, so NDI cannot read the file either
    ev = left(ev, 'other', ['NDI''s expander cannot read the events file (' ...
        err.message ')']);
    return;
end
ct = cellstr(ct);
ev.channels = numel(ct);
ev.textChannels = sum(strcmp(ct, 'text'));
if ~isfinite(t0)
    ev = left(ev, 'other', 'the v1 archive names no epoch start (t0_t1)');
    return;
end
% the recordings that own the file: their system and anchors
owners = edgeValues(b, 'owner_id');
sysIds = {}; anchors = {};
for k = 1:numel(structs)
    if ~any(strcmp(baseId(structs{k}), owners)); continue; end
    sysIds = [sysIds, edgeValues(structs{k}, 'acquisition_system_id')]; %#ok<AGROW>
    anchors = [anchors, edgeValues(structs{k}, 'time_reference_id')]; %#ok<AGROW>
end
sysIds = unique(sysIds);
anchors = unique(anchors, 'stable');
if ~isscalar(sysIds) || isempty(anchors)
    ev = left(ev, 'other', sprintf(['the recordings owning the events file name %d ' ...
        'acquisition system(s) and %d time reference(s)'], numel(sysIds), numel(anchors)));
    return;
end
[types, abbrev] = ndi.daq.reader.mfdaq.channel_types();
ciType = cellfun(@char, {ci.type}, 'UniformOutput', false);
plan = struct('type', {}, 'number', {}, 'name', {}, 'entity', {}, 'times', {}, 'codes', {}, ...
    'json', {});
for i = 1:numel(ct)
    type = ct{i};
    num = double(cn(i));
    r = find(strcmp(ciType, type) & double([ci.number]) == num, 1);
    if isempty(r) || ~any(strcmp(type, {'event', 'marker', 'text'}))
        ev = left(ev, 'other', sprintf('channel %s %d is not in the channel list', type, num));
        return;
    end
    Ti = T{i}; Di = D{i};
    if strcmp(type, 'text')
        % NDI-compress's expander gives a text channel's entries as a cell
        % of character rows (ndi.compress.vector2eventmarktext)
        dataOk = iscell(Di) && all(cellfun(@(x) ischar(x) && (isrow(x) || isempty(x)), Di));
    else
        dataOk = isa(Di, 'double');
    end
    if ~isa(Ti, 'double') || ~dataOk || isempty(Ti)
        if isempty(Ti)
            ev = left(ev, 'empty_channel', sprintf('%s channel %d has no event', type, num));
        else
            ev = left(ev, 'not_exact', sprintf(['%s channel %d: its times or data are not ' ...
                'what NDI''s expander gives (%s, %s)'], type, num, class(Ti), class(Di)));
        end
        return;
    end
    if strcmp(type, 'marker') && size(Di, 2) > 1
        ev = left(ev, 'marker_columns', sprintf(['marker channel %d carries %d numbers per ' ...
            'event: the second dimension has no decided term'], num, size(Di, 2)));
        return;
    end
    stored = Ti(:) - t0;
    codes = [];
    json = uint8([]);
    if strcmp(type, 'marker'); codes = Di(:); end
    if strcmp(type, 'text')
        if numel(Di) ~= numel(Ti)
            ev = left(ev, 'not_exact', sprintf('text channel %d has %d time(s) and %d entr(ies)', ...
                num, numel(Ti), numel(Di)));
            return;
        end
        % [text channel entries are a JSON array]: the entries as they will
        % be stored, and as the reader decodes them
        try
            json = ndi.vintage.ingestedTextEntries('encode', Di);
            codes = ndi.vintage.ingestedTextEntries('decode', json);
        catch err
            ev = left(ev, 'not_exact', sprintf(['text channel %d: its entries are not one ' ...
                'UTF-8 JSON array of strings (%s)'], num, err.message));
            return;
        end
    end
    [Tr, Dr] = ndi.vintage.ingestedEventData(type, stored, codes);
    if strcmp(type, 'text')
        sameData = isequal(Dr, Di);
    else
        sameData = isequal(Dr, Di(:));
    end
    if ~isequal(Tr + t0, Ti(:)) || ~sameData
        ev = left(ev, 'not_exact', sprintf(['%s channel %d does not read back exactly ' ...
            '(times from the epoch start %.17g, or its data)'], type, num, t0));
        return;
    end
    [entity, n] = wiredDevice(structs, sysIds{1}, anchors, type, num);
    if n ~= 1
        ev = left(ev, 'unwired', sprintf(['%s channel %d is wired to %d device(s) by a ' ...
            '`connected to` relation of the epoch: its entity is not known (the decision''s ' ...
            'fallback, the acquisition system, is not an entity)'], type, num, n));
        return;
    end
    plan(end+1) = struct('type', type, 'number', num, 'name', char(ci(r).name), ...
        'entity', entity, 'times', stored, 'codes', {codes}, 'json', json); %#ok<AGROW>
end
% NDI's own round trip: the file rebuilt from the unpacked values, expanded
try
    Tb = cell(1, numel(plan)); Db = cell(1, numel(plan));
    for i = 1:numel(plan)
        [Tb{i}, Db{i}] = ndi.vintage.ingestedEventData(plan(i).type, plan(i).times, plan(i).codes);
        Tb{i} = Tb{i} + t0;
    end
    stem2 = ndi.file.temp_name();
    ndi.compress.compress_eventmarktext({plan.type}, [plan.number], Tb, Db, stem2);
    c2 = onCleanup(@() deleteIfThere([stem2 '.nbf.tgz']));
    [ct2, cn2, T2, D2] = ndi.compress.expand_eventmarktext(stem2);
    same = isequal(cellstr(ct2), ct) && isequal(double(cn2(:)), double(cn(:))) ...
        && isequal(T2(:), T(:)) && isequal(D2(:), D(:));
catch err
    same = false;
    ev = left(ev, 'not_exact', sprintf('NDI''s round trip of the events file failed: %s', err.message));
    return;
end
if ~same
    ev = left(ev, 'not_exact', 'NDI''s round trip of the events file does not give it back');
    return;
end
[docs, written] = eventDocuments(b, plan, sysIds{1}, anchors, storeDir, types, abbrev);
ev.unpacked = true;
rows = struct('type', {plan.type}, 'number', {plan.number});
end

function ev = left(ev, kind, why)
ev.unpacked = false;
ev.kind = kind;
ev.why = why;
end

function [entity, n] = wiredDevice(structs, sysId, anchors, type, num)
% the child of the `connected to` (RO:0002170) relations to SYSID, timed by
% one of ANCHORS, whose condition of TYPE's channel-type term lists NUM
% (did2.convert.resolveEpochProbemap mkWiring); N how many devices. The
% relation's parent is the rig's device entity, the system's `device_id`
% (Jess Haley 2026-11-19 [acquisition system is a device entity], did-schema
% docs/plans/did_v2_standing_wiring_plan.md), or, in a batch migrated before,
% SYSID itself: both are read.
node = struct('event', 'EMPTY:0000376', 'marker', 'EMPTY:0000377', 'text', 'EMPTY:0000410');
want = node.(type);
parents = {sysId};
for k = 1:numel(structs)
    if any(strcmp(className(structs{k}), ndi.vintage.acquisitionConfigurationNames())) ...
            && strcmp(baseId(structs{k}), sysId)
        parents = [parents, edgeValues(structs{k}, 'device_id')]; %#ok<AGROW>
        break;
    end
end
found = {};
for k = 1:numel(structs)
    s = structs{k};
    if ~strcmp(className(s), 'directed_relation') || ~isfield(s, 'directed_relation'); continue; end
    dr = s.directed_relation;
    if ~isfield(dr, 'relation') || ~isstruct(dr.relation) || ~isfield(dr.relation, 'node') ...
            || ~strcmpi(char(dr.relation.node), 'RO:0002170')
        continue;
    end
    if ~any(ismember(edgeValues(s, 'parent_id'), parents)) ...
            || ~any(ismember(edgeValues(s, 'time_reference_id'), anchors))
        continue;
    end
    if ~isfield(dr, 'conditions') || isempty(dr.conditions); continue; end
    cs = dr.conditions;
    if isstruct(cs); cs = num2cell(cs); end
    for c = 1:numel(cs)
        cc = cs{c};
        if ~isstruct(cc) || ~isfield(cc, 'variable') || ~isstruct(cc.variable) ...
                || ~isfield(cc.variable, 'node') || ~strcmp(char(cc.variable.node), want)
            continue;
        end
        % the channel numbers: `numeric` (did-schema
        % did_v2_numeric_shape_plan.md, [one shape for measured numbers],
        % Jess Haley, 2026-11-17); the old `matrix` is not read (section 9
        % step 4, [no migrated database is kept], Jess Haley, 2026-11-19)
        old = ndi.v2.oldNumericForm(cc);
        if ~isempty(old)
            ndi.v2.refuseOldNumericShape('A wiring relation''s channel group', old);
        end
        if isfield(cc, 'numeric') && isnumeric(cc.numeric) && any(double(cc.numeric(:)) == num)
            found = [found, edgeValues(s, 'child_id')]; %#ok<AGROW>
        end
    end
end
found = unique(found);
n = numel(found);
entity = '';
if n == 1; entity = found{1}; end
end

function [docs, written] = eventDocuments(b, plan, sysId, anchors, storeDir, types, abbrev)
% the observations, time values and bodies of the unpacked channels, and
% their files (written last; deleted again if anything fails)
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
docs = {};
written = {};
srcId = baseId(b);
sid = char(did2.schema.cache.sessionIdOf(b));
tsArg = {};
if isfield(b.base, 'creation_timestamp') && ~isempty(b.base.creation_timestamp)
    tsArg = {'CreationTimestamp', char(b.base.creation_timestamp)};
end
timeTerm = struct('node', 'om:Time', 'name', 'time');
binary = struct('node', 'EDAM:format_2333', 'name', 'Binary format');
% [text channel entries are a JSON array]: did-schema term registry
% EDAM:format_3464 "JSON"
jsonFormat = struct('node', 'EDAM:format_3464', 'name', 'JSON');
chanTerm = struct('event', struct('node', 'EMPTY:0000376', 'name', 'event channel'), ...
    'marker', struct('node', 'EMPTY:0000377', 'name', 'marker channel'), ...
    'text', struct('node', 'EMPTY:0000410', 'name', 'text channel'));
variable = struct('event', struct('node', 'NCIT:C25499', 'name', 'Event'), ...
    'marker', struct('node', 'NCIT:C25162', 'name', 'Code'), ...
    'text', struct('node', 'NCIT:C44272', 'name', 'Annotation'));
try
    for i = 1:numel(plan)
        p = plan(i);
        key = sprintf('%s|%s|%d', srcId, p.type, p.number);
        obsId = did2.convert.mintId('unpacked event channel', key);
        n = numel(p.times);
        note = sprintf(['The %s channel %s of the ingested events file %s (v1 name %s), ' ...
            'unpacked by the NDI second pass: %d event(s), times in seconds from the ' ...
            'epoch''s start.'], p.type, sprintf('%s%d', abbrev{strcmp(types, p.type)}, p.number), ...
            bodyFilename(b), p.name, n);
        datumType = 'float64';
        if strcmp(p.type, 'text'); datumType = 'utf8'; end
        common = {'DataBody', true, 'DatumType', datumType, 'TimeReferenceIds', anchors, ...
            'AcquisitionSystemId', sysId, ...
            'Conditions', did2.build.condition(chanTerm.(p.type), 'Count', p.number), ...
            'Notes', note, 'Id', obsId, 'SessionId', sid, 'Validate', false, tsArg{:}};
        if strcmp(p.type, 'event')
            obs = did2.build.statement('observation', p.entity, variable.event, [], ...
                'ValueKind', 'time', common{:});
            [fi, w] = writeFloats(p.times, storeDir, ['times|' key]);
            written{end+1} = w; %#ok<AGROW>
            body = did2.build.sampledBody(obsId, did2.build.dimension(timeTerm, n), ...
                'ByteOrder', 'little', 'Format', binary, ...
                'Id', did2.convert.mintId('unpacked event channel body', key), ...
                'SessionId', sid, 'Validate', false, tsArg{:});
            body.files = struct('file_list', {{'body_data_0'}}, 'file_info', fi);
            docs = [docs, {obs, body}]; %#ok<AGROW>
        else
            tvId = did2.convert.mintId('unpacked event times value', key);
            tv = did2.build.document('time', struct('data_body', true, 'data_type', 'float64'), ...
                'Id', tvId, 'SessionId', sid, 'Validate', false, tsArg{:});
            [fi, w] = writeFloats(p.times, storeDir, ['times|' key]);
            written{end+1} = w; %#ok<AGROW>
            tbody = did2.build.sampledBody(tvId, did2.build.dimension(timeTerm, n), ...
                'ByteOrder', 'little', 'Format', binary, ...
                'Id', did2.convert.mintId('unpacked event times body', key), ...
                'SessionId', sid, 'Validate', false, tsArg{:});
            tbody.files = struct('file_list', {{'body_data_0'}}, 'file_info', fi);
            if strcmp(p.type, 'marker')
                obs = did2.build.statement('observation', p.entity, variable.marker, [], ...
                    'ValueKind', 'label', common{:});
                [fi, w] = writeFloats(p.codes, storeDir, ['codes|' key]);
                fmt = {'ByteOrder', 'little', 'Format', binary};
            else
                % a text channel's entries: one UTF-8 JSON array of strings
                obs = did2.build.statement('observation', p.entity, variable.text, [], ...
                    'ValueKind', 'text', common{:});
                [fi, w] = writeBytes(p.json, storeDir, ['entries|' key]);
                fmt = {'Format', jsonFormat};
            end
            written{end+1} = w; %#ok<AGROW>
            body = did2.build.sampledBody(obsId, did2.build.dimension(timeTerm, n), ...
                'Covariates', did2.build.covariate(timeTerm, 0, 'Key', 0), 'KeyIds', {tvId}, ...
                fmt{:}, ...
                'Id', did2.convert.mintId('unpacked event channel body', key), ...
                'SessionId', sid, 'Validate', false, tsArg{:});
            body.files = struct('file_list', {{'body_data_0'}}, 'file_info', fi);
            docs = [docs, {tv, tbody, obs, body}]; %#ok<AGROW>
        end
    end
catch err
    cellfun(@deleteIfThere, written);
    rethrow(err);
end
end

function [fi, dest] = writeFloats(x, storeDir, key)
% [unpacked event bodies are uncompressed]: little-endian float64, one
% member, into the store under a uid derived from KEY
[fi, dest] = writeMember(@(fid) fwrite(fid, double(x(:)), 'float64'), storeDir, key);
end

function [fi, dest] = writeBytes(bytes, storeDir, key)
% [text channel entries are a JSON array]: the bytes as given (UTF-8), one
% member, uncompressed
[fi, dest] = writeMember(@(fid) fwrite(fid, uint8(bytes(:)), 'uint8'), storeDir, key);
end

function [fi, dest] = writeMember(writeFcn, storeDir, key)
uid = char(did2.convert.mintId('unpacked event file', key));
dest = fullfile(storeDir, uid);
fid = fopen(dest, 'w', 'ieee-le');
if fid < 0
    error('NDI:migrate:ingestedArchiveBodies:write', 'Cannot write %s.', dest);
end
writeFcn(fid);
fclose(fid);
fi = struct('name', 'body_data_0', 'locations', struct('delete_original', 0, 'uid', uid, ...
    'location', dest, 'parameters', '', 'location_type', 'file', 'ingest', 1));
end

% ---- terms ----------------------------------------------------------

function t = CHANNEL_NUMBER()
% No existing ontology term found (OLS4, 2026-11-01); a label until one is
% registered (T19: report candidates rather than mint).
t = struct('node', '', 'name', 'channel number');
end

function t = OFFSET()
% v1 `offset`: the stored value is (raw + offset) * scale, so the offset is
% in the stored integer's units (Intan: 32768). AFO "signal offset
% configuration": "adds/subtracts a fixed amount of magnitude to the signal
% strength or amplitude to move the zero reference".
t = struct('node', 'AFO:AFQ_0000202', 'name', 'signal offset configuration');
end

function t = SCALE()
% v1 `scale`: what one stored unit is worth in the reader's output unit
% (Intan analog: 0.195, microvolts per count). NCIT "Unit Conversion
% Factor": "An operator used to convert units from one scale to another."
t = struct('node', 'NCIT:C70774', 'name', 'Unit Conversion Factor');
end

function t = IDENTIFIER()
% did-schema term registry NCIT:C25364 "Identifier", the variable of
% [channel name is an identifier]
t = struct('node', 'NCIT:C25364', 'name', 'Identifier');
end

function t = TIME_CHANNEL()
% did-schema term registry EMPTY:0000374 "time channel" ([channel types]),
% the variable of [time channel is a per-channel covariate]
t = struct('node', 'EMPTY:0000374', 'name', 'time channel');
end

function t = VOLT()
% the canonical unit of a voltage output (did-schema term registry om:volt)
t = struct('node', 'om:volt', 'name', 'volt');
end

% ---- the reader's output unit ([scale carries the reader's unit]) ----

function [perVolt, sourceUnit, why] = readerUnit(reader, type)
%READERUNIT What one unit of the reader's output for channel type TYPE is in
%   volts (PERVOLT), and that output unit as a term (SOURCEUNIT), where NDI's
%   reader for the system defines it; otherwise WHY says why not (PERVOLT
%   NaN, SOURCEUNIT empty). Only a unit with positive evidence in the
%   reader's code is listed here:
%
%   Intan RHD (ndi.daq.reader.mfdaq.intan; ndi.daq.reader.mfdaq.ndr with an
%   NDR reader string of ndr.reader.intan_rhd: intan, RHD, intanRHD)
%     analog_in     microvolt. Both readers' underlying_datatype give
%                   [32768 0.195] (NDI +daq/+reader/+mfdaq/intan.m; NDR
%                   +ndr/+reader/intan_rhd.m), the Intan amplifier's
%                   resolution, and NDR's Intan file reader scales the
%                   amplifier block by 0.195 with shift 32768
%                   (+ndr/+format/+intan/Intan_RHD2000_blockinfo.m); Intan's
%                   own reader says "amplifier_data = 0.195 *
%                   (amplifier_data - 32768); % units = microvolts"
%                   (+ndr/+format/+intan/+manufacturer/read_Intan_RHD2000_file.m).
%     auxiliary_in  volt. underlying_datatype [0 3.74e-05]; "aux_input_data =
%                   37.4e-6 * aux_input_data; % units = volts" (the same
%                   file); blockinfo 'aux' scale 37.4e-6.
%   Blackrock (ndi.daq.reader.mfdaq.blackrock)
%     analog_in     microvolt. Its readchannels_epochsamples reads with
%                   openNSx(..., 'uV', ...) and it keeps the base class's
%                   [0 1] polynomial, so one count is one microvolt.
%
%   Every other reader and channel type (CED Spike2 whose unit is per
%   channel in the file, the other NDR readers, NDI's base reader) has no
%   unit defined by the reader: a gap. Digital channels (`di`, `do`) record a
%   logic level: the caller writes their scale with no unit and lists no gap
%   ([digital scale is unitless], Jess Haley, 2026-11-17).
perVolt = NaN;
sourceUnit = struct('node', '', 'name', '');
why = '';
if isempty(reader)
    why = ['the v1 archive''s daqreader document (its daqreader_id) is not among ' ...
        'this session''s v1 documents, so the reader that defines the unit of the ' ...
        'v1 channel_list.bin scale is not known'];
    return;
end
cls = reader.class;
family = '';
if any(strcmp(cls, {'ndi.daq.reader.mfdaq.intan', 'ndi_daqreader_mfdaq_intan'}))
    family = 'intan';
elseif any(strcmp(cls, {'ndi.daq.reader.mfdaq.blackrock', 'ndi_daqreader_mfdaq_blackrock'}))
    family = 'blackrock';
elseif strcmp(cls, 'ndi.daq.reader.mfdaq.ndr') ...
        && any(strcmpi(reader.ndr_reader_string, {'intan', 'RHD', 'intanRHD'}))
    family = 'intan';
end
microvolt = struct('node', 'om:microvolt', 'name', 'microvolt');
volt = struct('node', 'om:volt', 'name', 'volt');
switch [family '|' type]
    case 'intan|analog_in'
        perVolt = 1e-6; sourceUnit = microvolt;
    case 'intan|auxiliary_in'
        perVolt = 1; sourceUnit = volt;
    case 'blackrock|analog_in'
        perVolt = 1e-6; sourceUnit = microvolt;
    otherwise
        name = cls;
        if strcmp(cls, 'ndi.daq.reader.mfdaq.ndr')
            name = sprintf('%s (NDR reader "%s")', cls, reader.ndr_reader_string);
        end
        if isempty(name); name = '(no class named)'; end
        why = sprintf(['NDI''s reader %s does not define the unit of its %s output, so ' ...
            'the per-channel scale (v1 channel_list.bin `scale`) is written with no ' ...
            'unit ([scale carries the reader''s unit])'], name, type);
end
end

function [node, label] = channelTypeTerm(ab)
T = ndi.vintage.channelTypes();
node = T{strcmp(T(:, 1), ab), 2};
labels = {'ai', 'analog input channel'; 'ao', 'analog output channel'; ...
    'di', 'digital input channel'; 'do', 'digital output channel'; ...
    't', 'time channel'; 'ax', 'auxiliary input channel'};
label = labels{strcmp(labels(:, 1), ab), 2};
end

% ---- the files ------------------------------------------------------

function kind = seriesKind(fn)
% 'group' (ai ao ax di do), 'time' (ti), 'event' (evmktx), 'channel_list', or ''
kind = '';
if strcmp(fn, 'channel_list.bin'); kind = 'channel_list'; return; end
tok = regexp(fn, '^(ai|ao|ax|di|do|ti|evmktx)_group\d+_seg\.nbf_#$', 'tokens', 'once');
if isempty(tok); return; end
switch tok{1}
    case 'ti', kind = 'time';
    case 'evmktx', kind = 'event';
    otherwise, kind = 'group';
end
end

function [prefix, g] = prefixAndGroup(fn)
tok = regexp(fn, '^([a-z]+)_group(\d+)_seg', 'tokens', 'once');
prefix = tok{1};
g = str2double(tok{2});
end

function data = expandSegment(path, dataclass)
% NDI's compressed segment, read with NDI's own expander (the file must end
% .nbf.tgz, as ndi.daq.reader.mfdaq's copydocfile2temp names it)
stem = ndi.file.temp_name();
tmp = [stem '.nbf.tgz'];
copyfile(path, tmp);
c = onCleanup(@() deleteIfThere(tmp));
switch dataclass
    case 'ephys',   data = ndi.compress.expand_ephys(stem);
    case 'digital', data = ndi.compress.expand_digital(stem);
    case 'time',    data = ndi.compress.expand_time(stem);
end
end

function deleteIfThere(f)
if isfile(f); delete(f); end
end

function paths = memberPaths(b, storeDir)
% the local path of every member body_data_0..N-1, in order; {} if any is
% not here
paths = {};
if ~isfield(b, 'files') || ~isstruct(b.files) || ~isfield(b.files, 'file_info')
    return;
end
infos = b.files.file_info;
if isstruct(infos); infos = num2cell(infos); end
names = cellfun(@(f) char(f.name), infos, 'UniformOutput', false);
out = cell(1, numel(infos));
for m = 1:numel(infos)
    i = find(strcmp(names, sprintf('body_data_%d', m - 1)), 1);
    if isempty(i); paths = {}; return; end
    p = locatedHere(infos{i}, storeDir);
    if isempty(p); paths = {}; return; end
    out{m} = p;
end
paths = out;
end

function path = locatedHere(fi, storeDir)
path = '';
if ~isstruct(fi) || ~isfield(fi, 'locations'); return; end
locs = fi.locations;
if isstruct(locs); locs = num2cell(locs); end
for j = 1:numel(locs)
    L = locs{j};
    if isstruct(L) && isfield(L, 'uid') && ~isempty(L.uid) ...
            && did.file.isSafeUid(char(L.uid)) ...
            && isfile(fullfile(storeDir, char(L.uid)))
        path = fullfile(storeDir, char(L.uid));
        return;
    end
end
for j = 1:numel(locs)
    L = locs{j};
    if ~isstruct(L) || ~isfield(L, 'location') || isempty(L.location); continue; end
    type = 'file';
    if isfield(L, 'location_type') && ~isempty(L.location_type)
        type = lower(strtrim(char(L.location_type)));
    end
    if strcmp(type, 'file') && isfile(char(L.location))
        path = char(L.location);
        return;
    end
end
end

% ---- the v1 archive -------------------------------------------------

function m = v1ArchivesByUid(v1Bodies)
% file uid -> the v1 daqreader_mfdaq_epochdata_ingested struct holding it
m = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(v1Bodies)
    b = v1Bodies{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        if ~contains(b, 'daqreader_mfdaq_epochdata_ingested'); continue; end
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    if ~isstruct(b) || ~isscalar(b) || ~isfield(b, 'daqreader_mfdaq_epochdata_ingested')
        continue;
    end
    if ~isfield(b, 'files') || ~isstruct(b.files) || ~isfield(b.files, 'file_info')
        continue;
    end
    infos = b.files.file_info;
    if isstruct(infos); infos = num2cell(infos); end
    for i = 1:numel(infos)
        if ~isstruct(infos{i}) || ~isfield(infos{i}, 'locations'); continue; end
        locs = infos{i}.locations;
        if isstruct(locs); locs = num2cell(locs); end
        for j = 1:numel(locs)
            if isstruct(locs{j}) && isfield(locs{j}, 'uid') && ~isempty(locs{j}.uid)
                m(char(locs{j}.uid)) = b;
            end
        end
    end
end
end

function m = v1ReadersById(v1Bodies)
% v1 daqreader document id -> struct {class, ndr_reader_string}: what
% [scale carries the reader's unit] reads to find the reader's output unit
m = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(v1Bodies)
    b = v1Bodies{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        if ~contains(b, 'ndi_daqreader_class'); continue; end
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    if ~isstruct(b) || ~isscalar(b) || ~isfield(b, 'daqreader') ...
            || ~isstruct(b.daqreader) || ~isfield(b.daqreader, 'ndi_daqreader_class')
        continue;
    end
    id = baseId(b);
    if isempty(id); continue; end
    r = struct('class', strtrim(char(b.daqreader.ndi_daqreader_class)), ...
        'ndr_reader_string', '');
    if isfield(b, 'daqreader_ndr') && isstruct(b.daqreader_ndr) ...
            && isfield(b.daqreader_ndr, 'ndr_reader_string')
        r.ndr_reader_string = strtrim(char(b.daqreader_ndr.ndr_reader_string));
    end
    m(id) = r;
end
end

function r = readerOf(arch, readers)
% the v1 daqreader of the archive (its `daqreader_id`), or [] when it is not
% among the v1 documents
r = [];
ids = edgeValues(arch, 'daqreader_id');
if isscalar(ids) && isKey(readers, ids{1})
    r = readers(ids{1});
end
end

function arch = archiveOf(bodies, archives)
% the one v1 archive every member of these bodies came from; [] otherwise
arch = [];
archId = '';
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isfield(b, 'files') || ~isfield(b.files, 'file_info'); continue; end
    infos = b.files.file_info;
    if isstruct(infos); infos = num2cell(infos); end
    for i = 1:numel(infos)
        if ~isfield(infos{i}, 'locations'); continue; end
        locs = infos{i}.locations;
        if isstruct(locs); locs = num2cell(locs); end
        for j = 1:numel(locs)
            if ~isfield(locs{j}, 'uid') || isempty(locs{j}.uid) ...
                    || ~isKey(archives, char(locs{j}.uid))
                arch = [];
                return;
            end
            a = archives(char(locs{j}.uid));
            if isempty(archId)
                archId = baseId(a);
                arch = a;
            elseif ~strcmp(archId, baseId(a))
                arch = [];
                return;
            end
        end
    end
end
end

function t0 = epochStart(arch)
t0 = NaN;
try
    tt = double(arch.daqreader_epochdata_ingested.epochtable.t0_t1);
    if ~isempty(tt); t0 = tt(1); end
catch
end
end

function v = paramOf(params, name)
v = NaN;
if isstruct(params) && isfield(params, name) && ~isempty(params.(name))
    v = double(params.(name));
end
end

% ---- document fields ------------------------------------------------

function key = archiveKeyOf(b)
% pass 1 makes one archive's bodies together: the same owners, session and
% epoch note ("The ingested recording of epoch <e>: ...")
owners = sort(edgeValues(b, 'owner_id'));
sid = char(did2.schema.cache.sessionIdOf(b));
note = '';
if isfield(b, 'data_body'); note = ndi.v2.notesOf(b.data_body); end
tok = regexp(note, 'recording of epoch (.*?): v1 attached', 'tokens', 'once');
ep = '';
if ~isempty(tok); ep = tok{1}; end
key = strjoin([{sid, ep}, owners], '|');
end

function fn = bodyFilename(b)
fn = '';
if isfield(b, 'data_body') && isstruct(b.data_body) && isfield(b.data_body, 'filename')
    fn = char(b.data_body.filename);
end
end

function c = className(b)
c = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    c = char(b.document_class.class_name);
end
end

function id = baseId(b)
id = '';
if isstruct(b) && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id')
    id = char(b.base.id);
end
end

function vals = edgeValues(b, name)
vals = {};
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    if isfield(d, 'value') && ~isempty(d.value)
        vals{end+1} = char(d.value); %#ok<AGROW>
    elseif isfield(d, 'document_id') && ~isempty(d.document_id)
        vals{end+1} = char(d.document_id); %#ok<AGROW>
    end
end
end
