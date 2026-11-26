function key = ingestedStimulusLogKey(epochId, readerId)
%INGESTEDSTIMULUSLOGKEY How a migrated stimulus log names its epoch and reader.
%
%   KEY = ndi.vintage.ingestedStimulusLogKey(EPOCHID, READERID) is the text
%   that opens the `data_body.notes` of each data body a stimulus system's
%   ingested archive files become:
%
%       The stimulus log of epoch <EPOCHID>, read by the NDI reader <READERID>.
%
%   followed by a space and the rest of the description.
%
%   Decided by Jess Haley, 2026-11-19 [stimulus log owned by its
%   presentation] (did-schema docs/plans/did_v2_standing_wiring_plan.md): an
%   epoch's stimulus-system archive files (the event file
%   `evmktx_group1_seg.nbf_1` and `channel_list.bin`, read by
%   ndi.setup.daq.reader.mfdaq.stimulus.vhlabvisspike2) become a data body
%   of that epoch's stimulus-presentation manipulation; where the epoch has
%   no presentation, a manipulation of the epoch's subject owns them, the
%   stimulator its instrument (amended 2026-11-25 [stimulus log fallback is
%   a manipulation]; before, an observation of the stimulus rig's device).
%   The archive document then goes.
%
%   WHY A KEY. A presentation names no acquisition system, so the readers'
%   usual route to an epoch's bodies (a statement timed onto the epoch that
%   names one of the reader's systems, ndi.vintage.ingestedArchive) does not
%   reach it, and data_body has no epoch or reader field. The body records
%   both here, as the migrated ingested stimulus file does
%   (ndi.vintage.ingestedStimulusKey, [ingested stimulus reader finds the
%   body], Jess Haley, 2026-10-26). DID-matlab's
%   did2.convert.resolveEpochProbemap writes the same text (it cannot call
%   this function: DID-matlab does not depend on NDI-matlab), so a change
%   here is a change there.
%
%   The epoch id ends at ", read by" and the reader id at the final ".", so
%   a key never matches another epoch or reader as a prefix ('t0007' and
%   't00074').
%
%   KEY = ndi.vintage.ingestedStimulusLogKey('', READERID) is the part that
%   names the reader only (", read by the NDI reader <READERID>."), which
%   ndi.vintage.ingestedStimulusLogBodies searches for when it reads many
%   epochs at once.
%
%   See also ndi.vintage.ingestedStimulusLogBodies,
%            ndi.vintage.ingestedArchive, ndi.vintage.ingestedStimulusKey.

arguments
    epochId {mustBeText}
    readerId {mustBeText}
end

readerPart = sprintf(', read by the NDI reader %s.', char(readerId));
if isempty(char(epochId))
    key = readerPart;
else
    key = sprintf('The stimulus log of epoch %s%s', char(epochId), readerPart);
end
end
