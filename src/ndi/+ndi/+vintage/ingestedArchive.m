function A = ingestedArchive(S, readerId, epochId, options)
%INGESTEDARCHIVE An ingested mfdaq epoch's data, read from its v2 data bodies.
%
%   A = ndi.vintage.ingestedArchive(SESSION, READERID, EPOCHID) finds, in a
%   v2 session, what NDI's mfdaq reader reads from a v1
%   `daqreader_mfdaq_epochdata_ingested` document for the ingested epoch
%   EPOCHID ('epoch_...', the `local_identifier` of the epoch entity) of the
%   reader READERID:
%
%     the epoch          the `entity` whose local_identifier is EPOCHID
%     its recordings     the statements timed by a relative_time_reference
%                        onto that epoch (time_reference_id -> referent_id)
%                        whose `acquisition_system_id` names a system whose
%                        `reader_id` is READERID
%     their data         the data bodies those statements own (owner_id),
%                        one per v1 attached file series, named by the v1
%                        series name in `data_body.filename`
%                        (`ai_group1_seg.nbf_#`, `channel_list.bin`, ...)
%
%   Decided by Jess Haley, 2026-10-29 [V2 ingest is one sampled body per
%   channel group] (did-schema did_v2_go_forward_class_audit.md): "a reader
%   finds an epoch's data through those bodies, not through the v1
%   `daqreader_mfdaq_epochdata_ingested` document". Migration writes that
%   shape ([ingested archives are sampled bodies]; DID-matlab
%   did2.convert.resolveEpochProbemap carries each v1 file series as an
%   opaque_body, ndi.migrate.internal.ingestedArchiveBodies turns each
%   channel group into a sampled_body). Both are read:
%
%     a sampled_body    its time dimension's `chunk` is the v1 segment length
%                       ([segment length is the time chunk]) and its `n` the
%                       number of samples; its covariates hold the channel
%                       list (channel number, offset, scale, and the sample
%                       rate as the time covariate's spacing)
%     an opaque_body    the v1 series as pass 1 carried it: member
%                       body_data_<k> is v1 segment k+1. Its segment length
%                       is the length of its first member when it has more
%                       than one (a single member holds the whole epoch)
%
%   A is a struct:
%
%     vintage       'v2'
%     epoch_id      EPOCHID
%     bodies        containers.Map, series name -> struct with fields
%                     doc     the body (ndi.document)
%                     kind    'sampled_body' or 'opaque_body'
%                     n       samples along time ([] when not stated)
%                     chunk   samples per member ([] when not stated)
%                     members the number of body_data_<k> members
%     channels      the v1 channel list (ndi.file.type.mfdaq_epoch_channel
%                   channel_information): read from the `channel_list.bin`
%                   body when there is one; otherwise rebuilt from the
%                   sampled bodies' covariates (each row named by its v1
%                   prefix and number, time_channel NaN: the second pass
%                   removes channel_list.bin only when every row is of that
%                   kind)
%     epochclock    cellstr, the ndi.time.clocktype strings of the clocks on
%                   which the epoch's extent is stated
%     t0_t1         cell, [t0 t1] on each of those clocks
%     clock_problem '' or, when no clock is stated, why
%
%   THE EPOCH'S CLOCK AND EXTENT. Decided by Jess Haley, 2026-11-01 [clock
%   only on the time reference]: "an ingested or migrated data body names no
%   clock: its time axis counts seconds from the start of the epoch ..., and
%   the recording observation's time references say when the epoch starts on
%   each clock". They are read from
%     1. the recordings' time references, and
%     2. any other relative_time_reference onto the epoch,
%   each one that states a clock and a start (and an end or duration), the
%   shape DID-matlab's jEpochClockReferences writes from a v1 epochtable
%   (clock, start, duration). When none does, EPOCHCLOCK and T0_T1 are empty
%   and CLOCK_PROBLEM says so; the reader then refuses to report a clock
%   rather than assume one.
%
%   A = ndi.vintage.ingestedArchive(..., 'Channels', false) leaves
%   CHANNELS empty and reads no data body file: the epoch's clock and
%   extent are documents, so the epoch table (EPOCHCLOCK_INGESTED,
%   T0_T1_INGESTED) is read without the epoch's data, as v1 read it from
%   the `daqreader_epochdata_ingested` document alone. Without it, every
%   epoch table of a migrated session opened every epoch's channel list,
%   and failed where the data were not on the computer (the B corpus,
%   VH-Lab/NDI-matlab#785 corpus equivalence).
%
%   See also ndi.vintage.ingestedArchives (every epoch of a reader at once),
%            ndi.daq.reader/getingestedarchive, ndi.daq.reader.mfdaq,
%            ndi.migrate.internal.ingestedArchiveBodies,
%            ndi.vintage.ingestedEpochs.

arguments
    S
    readerId (1,:) char
    epochId (1,:) char
    options.Channels (1,1) logical = true
end

inSession = ndi.query('base.session_id', 'exact_string', S.id(), '');

% ---- the epoch -------------------------------------------------------
epochs = S.database_search(ndi.query('', 'isa', 'entity', '') & ...
    ndi.query('entity.local_identifier', 'exact_string', epochId, '') & inSession);
if isempty(epochs)
    error('NDI:daq:reader:ingestedNoEpoch', ...
        'No v2 epoch entity has local_identifier %s.', epochId);
end
epochIds = cellfun(@(d) d.id(), epochs, 'UniformOutput', false);
anchors = S.database_search(ndi.query('', 'isa', 'relative_time_reference', '') & ...
    ndi.v2.anyOf(cellfun(@(i) ndi.query('', 'depends_on', 'referent_id', i), ...
        epochIds, 'UniformOutput', false)));
anchorIds = cellfun(@(d) d.id(), anchors, 'UniformOutput', false);

% ---- this reader's systems and their recordings of the epoch ---------
systems = S.database_search(ndi.query('', 'isa', 'acquisition_system', '') & ...
    ndi.query('', 'depends_on', 'reader_id', readerId) & inSession);
statements = {};
if ~isempty(anchors) && ~isempty(systems)
    statements = S.database_search(ndi.v2.isaQuery('statement') & ...
        ndi.v2.anyOf(cellfun(@(i) ndi.query('', 'depends_on', 'time_reference_id', i), ...
            anchorIds, 'UniformOutput', false)) & ...
        ndi.v2.anyOf(cellfun(@(d) ndi.query('', 'depends_on', 'acquisition_system_id', d.id()), ...
            systems, 'UniformOutput', false)));
end
if isempty(statements)
    error('NDI:daq:reader:ingestedNoRecording', ...
        'No v2 recording of epoch %s names an acquisition system read by reader %s.', ...
        epochId, readerId);
end

% ---- the bodies they own ---------------------------------------------
bodies = S.database_search(ndi.query('', 'isa', 'data_body', '') & ...
    ndi.v2.anyOf(cellfun(@(d) ndi.query('', 'depends_on', 'owner_id', d.id()), ...
        statements, 'UniformOutput', false)));

A = archiveOf(S, epochId, anchors, statements, bodies, options.Channels);
end
