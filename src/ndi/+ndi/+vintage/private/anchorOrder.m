function order = anchorOrder(anchorIds, used)
%ANCHORORDER The order an epoch's clocks are read from its anchors in.
%
%   ORDER = anchorOrder(ANCHORIDS, USED) indexes ANCHORIDS (a cellstr: the
%   relative_time_references onto an epoch, in the order the database
%   returned them): first the anchors USED names (the `time_reference_id`
%   edges of the epoch's recordings, each document's edges in the order it
%   lists them), in the order USED names them; then the anchors no
%   recording names, in database order. ORDER is a row.
%
%   WHY USED'S ORDER, NOT THE DATABASE'S. DID-matlab's resolveEpochProbemap
%   gives each recording observation its epoch's clock references in the v1
%   epoch table's clock order (did2.convert.epochClockReferences over
%   `epochtable.epochclock`), so a recording's edges hold v1's epoch_clock
%   order. The database's order is the order the documents were written in,
%   which says nothing about the clocks: it followed the clock order only
%   while the references' ids were random ids that sort in the order they
%   were made, because the migration emits them sorted by id
%   (resolveEpochProbemap's clockBodyById.values). Since their ids are
%   derived from their source (DID-matlab #453, [migration reliability
%   practices] (b)), about half of Dab's epochs read their clocks swapped
%   (NDI-matlab corpusObjectEquivalence: epoch_clock v1
%   ["dev_local_time","exp_global_time"], migrated
%   ["exp_global_time","dev_local_time"]).
%
%   Used by private/archiveOf and ndi.vintage.ingestedArchives ('ClocksOnly'),
%   so the two reads agree.

anchorIds = reshape(cellstr(anchorIds), 1, []);
used = reshape(cellstr(used), 1, []);
[~, at] = ismember(used, anchorIds);
at = reshape(unique(at(at > 0), 'stable'), 1, []);
rest = reshape(find(~ismember(anchorIds, used)), 1, []);
order = [at, rest];
end
