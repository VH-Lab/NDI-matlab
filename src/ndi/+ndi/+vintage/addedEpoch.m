function [epochId, clockTypes, t0t1, found, shape] = addedEpoch(ndi_document_obj)
%ADDEDEPOCH One added-epoch record, read from whichever shape it is stored in.
%
%   [EPOCHID, CLOCKTYPES, T0T1, FOUND, SHAPE] = ndi.vintage.addedEpoch(DOC)
%
%   DOC is a candidate epoch document -- one of the documents
%   `ndi.element.load_all_element_docs` returns. FOUND is false when DOC is
%   not an added-epoch document at all, which is the ordinary case: that
%   query returns the element document itself and every other document
%   depending on it.
%
%   CLOCKTYPES is a 1-by-N cell of ndi.time.clocktype and T0T1 a 1-by-N cell
%   of 1-by-2 doubles, parallel, in the shape `ndi.element.buildepochtable`
%   wants. SHAPE names which storage this document used, for diagnostics.
%
%   ---------------------------------------------------------------------
%   THREE SHAPES EXIST AND ALL THREE ARE LIVE. THIS IS NOT A MIGRATION
%   SHIM THAT CAN BE DELETED WHEN V_eta LANDS.
%   ---------------------------------------------------------------------
%
%     'v1'      block `element_epoch`, fields `epoch_clock` (a
%               comma-separated char) and `t0_t1` (2-by-N, columns =
%               clocks). THIS IS WHAT NDI WRITES TODAY --
%               ndi.element.addepoch, element.m:424-427:
%
%                   epochdoc = E.newdocument('element_epoch', ...
%                       'element_epoch.epoch_clock', epochclockstr, ...
%                       'element_epoch.t0_t1', t0_t1_input, ...
%                       'epochid.epochid', epochid);
%
%     'clocks'  block `element_epoch`, field `clocks`: an array of records
%               {name, t0, t1}. The V_delta restructure, kept rather than
%               reverted by team decision (NDI-matlab bcc6b4e14,
%               2026-05-22: "the user elected to keep V_delta's new
%               structural shape").
%
%     'V_eta'   block `acquisition_epoch`, same `clocks` records. The
%               migrator renames the class and its block and reuses the
%               V_delta clock transform verbatim
%               (DID-matlab +migrators_j/element_epoch.m).
%
%   ---------------------------------------------------------------------
%   WHY THIS FUNCTION EXISTS: THE READER COULD READ NONE OF WHAT NDI
%   WRITES, AND HAD NOT BEEN ABLE TO SINCE MAY
%   ---------------------------------------------------------------------
%   `loadaddedepochs` handled exactly ONE of the three, and not the one
%   NDI emits. It gated on `isfield(...,'element_epoch')` and then read
%   `.clocks` -- so:
%
%     * a V_eta document failed the GATE (its block is
%       `acquisition_epoch`) and was skipped SILENTLY. Measured on
%       migrated 20211116, NDI-matlab e2e run 73:
%
%           DENOMINATOR: 1220 source body(ies); 21 derived
%                        (direct==false) element(s); 12 distinct epoch id(s)
%           MEASURED: 21 derived element object(s) driven; 0 returned a
%                     non-empty epoch table; 0 (element,epoch) pair(s);
%                     0 ERRORED
%
%     * a v1 document passed the gate and then asked a struct with no
%       `clocks` field for `.clocks`. `origin/main` still reads the v1
%       shape correctly at its own element.m:423-428; this branch replaced
%       that read and left the WRITER alone, so on this branch an element
%       could not read back an epoch it had just added.
%
%   Both are the same defect -- a reader pinned to one vintage -- and the
%   second is the one no corpus would ever have caught, because no corpus
%   contains a document NDI wrote after the reader changed.
%
%   THE ORIENTATION OF v1 `t0_t1` IS TAKEN FROM TWO AGREEING SOURCES, not
%   chosen here. `origin/main` element.m indexes `t0_t1(:,k)` (columns =
%   clocks), and DID-matlab `+migrators/element_epoch.m:28-32` canonicalises
%   the same way with the same worked example. A third description
%   disagrees -- `acquisition_epoch.json`'s `clocks` documentation says v1's
%   "N x 2 `t0_t1` splits row-wise" -- and it is NOT followed: two
%   implementations beat one prose sentence. Nothing in reach exercises the
%   difference (all 252 element_epoch documents in 20211116 carry ONE clock
%   and a flat 2-vector; 0 have a comma in `epoch_clock`), so this is
%   recorded as unexercised rather than settled.
%
%   See also: ndi.vintage.map, ndi.vintage.entryFor, ndi.element.

arguments
    ndi_document_obj
end

epochId = '';
clockTypes = {};
t0t1 = {};
found = false;
shape = '';

props = ndi_document_obj.document_properties;

% THE BLOCK IS LOCATED BY PRESENCE, NOT BY CLASS NAME, and that is
% deliberate: `oneepoch` documents carry an `element_epoch` BLOCK
% (ndi.element.addepoch writes `element_epoch.epoch_clock` into a document
% whose class is `oneepoch`, element.m:429-433). Keying on the class would
% drop them, which the code this replaces did not do.
if isfield(props, 'acquisition_epoch') && isstruct(props.acquisition_epoch)
    blk = props.acquisition_epoch;
    etaVintage = true;
elseif isfield(props, 'element_epoch') && isstruct(props.element_epoch)
    blk = props.element_epoch;
    etaVintage = false;
else
    return;
end
if ~isscalar(blk)
    return;
end

% The epoch id string. Both vintages carry the `epochid` MIXIN --
% acquisition_epoch's superclass chain is {base, epochid}, so the block
% survives the rename. Absence is a malformed document rather than another
% vintage, and it is refused (FOUND stays false) instead of yielding a
% record with a blank id that would join nothing.
if ~isfield(props, 'epochid') || ~isstruct(props.epochid) ...
        || ~isfield(props.epochid, 'epochid')
    return;
end
epochId = char(props.epochid.epochid);
if isempty(epochId)
    epochId = '';
    return;
end

if isfield(blk, 'clocks')
    [clockTypes, t0t1] = fromClockRecords(blk.clocks);
    if etaVintage
        shape = 'V_eta';
    else
        shape = 'clocks';
    end
elseif isfield(blk, 'epoch_clock') && isfield(blk, 't0_t1')
    [clockTypes, t0t1] = fromParallelFields(blk.epoch_clock, blk.t0_t1);
    shape = 'v1';
else
    epochId = '';
    return;
end

% A record with no clock is not an epoch table row: `buildepochtable`
% indexes `epoch_clock{1}` unconditionally, so admitting one would move a
% silent empty into a loud index error one caller away.
if isempty(clockTypes)
    epochId = '';
    clockTypes = {};
    t0t1 = {};
    shape = '';
    return;
end
found = true;
end

% ===================== the three shapes ================================

function [clockTypes, t0t1] = fromClockRecords(clocks)
%FROMCLOCKRECORDS The V_delta / V_eta array-of-records {name, t0, t1}.
clockTypes = {};
t0t1 = {};
% A one-element array decodes as a SCALAR struct and an N-element array as
% a struct array; a heterogeneous decode can arrive as a cell. numel()
% covers the first two and the cell is normalised rather than refused,
% because refusing would look exactly like "this document has no clocks".
if iscell(clocks)
    entries = clocks;
elseif isstruct(clocks)
    entries = num2cell(clocks);
else
    return;
end
for k = 1:numel(entries)
    entry = entries{k};
    if ~isstruct(entry) || ~isscalar(entry) ...
            || ~isfield(entry, 'name') || ~isfield(entry, 't0') ...
            || ~isfield(entry, 't1')
        continue;
    end
    name = char(entry.name);
    if isempty(name)
        continue;
    end
    clockTypes{end+1} = ndi.time.clocktype(name); %#ok<AGROW>
    t0t1{end+1} = vlt.data.rowvec(double([entry.t0, entry.t1])); %#ok<AGROW>
end
end

function [clockTypes, t0t1] = fromParallelFields(epochClock, rawT0T1)
%FROMPARALLELFIELDS The did_v1 pair: a CSV of clock names + a 2-by-N matrix.
%   Restores what `origin/main` element.m does, with the out-of-range guard
%   it does not have.
clockTypes = {};
t0t1 = {};
raw = char(epochClock);
if isempty(raw)
    return;
end
names = strtrim(strsplit(raw, ','));
m = double(rawT0T1);
% jsondecode turns a flat JSON array of two numbers into a 2-by-1 COLUMN,
% which is already the canonical single-clock case; a 1-by-2 row is the
% same fact written the other way and is transposed rather than refused.
if isvector(m) && numel(m) == 2
    m = reshape(m, 2, 1);
end
for k = 1:numel(names)
    if isempty(names{k})
        continue;
    end
    if size(m, 1) < 2 || size(m, 2) < k
        % NAMED MORE CLOCKS THAN THERE ARE TIME COLUMNS. Skipped rather
        % than padded with zeros: a fabricated [0 0] extent reads as a
        % real epoch of zero length, and a clock we cannot time is one we
        % must not claim to have.
        continue;
    end
    clockTypes{end+1} = ndi.time.clocktype(names{k}); %#ok<AGROW>
    t0t1{end+1} = vlt.data.rowvec(m(:, k)); %#ok<AGROW>
end
end
