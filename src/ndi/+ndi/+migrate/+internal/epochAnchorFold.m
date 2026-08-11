function [plan, report] = epochAnchorFold(migratedStructs, epochIndex)
%EPOCHANCHORFOLD Fold the NDI path's `epoch_bounded_reference` placeholders into
%   `relative_reference`, anchored to the `epoch` document did2.convert.epochMint
%   minted for the SAME (session, epoch-id string) PAIR.
%
%   ---------------------------------------------------------------------
%   STATUS: written 2026-08-11 in a container with no MATLAB. FIRST EXECUTED the
%   same day by test-eta-migrate.yml run 31463051482 (af840428f), which is where
%   the line above this one -- "NOTHING IN THIS FILE HAS BEEN EXECUTED" -- stopped
%   being true. TestEpochAnchorFold drove it 22 times: 21 assertions green, and
%   the single red one was an off-by-one in the TEST's expected denominator (it
%   said 4 documents over a 3-document fixture), not a defect here. NO LINE OF
%   THIS FILE WAS CHANGED IN RESPONSE. Still unexecuted against a real corpus:
%   green here means self-consistent with a test by the same author, nothing more.
%   ---------------------------------------------------------------------
%
%   WHY THIS EXISTS
%   ---------------------------------------------------------------------
%   `ndi.migrate.internal.stimulusBathToBath` is the ONLY site in either repo
%   that mints an `epoch_bounded_reference` DOCUMENT. Measured, working trees of
%   both repositories, 2026-08-11, BEFORE the commit that added this file:
%
%       $ cd NDI-matlab && grep -rn "epoch_bounded_reference" . | grep -v '^./.git/'
%       DENOMINATOR: 8 files, 21 lines.  Exactly ONE constructs a document
%                    class: +migrate/+internal/stimulusBathToBath, in the
%                    `if mintReference` block.
%                    The other 20 lines are comments, workflow prose and the
%                    four assertions in TestBathAssembly / TestMigrateLocalZeta
%                    / TestMigrateLocalEpsilon.
%
%       $ cd DID-matlab && grep -rn "epoch_bounded_reference" . | grep -v '^./.git/'
%       DENOMINATOR: 8 files, 15 lines.  ZERO construct a document class.
%                    +migrators_j/syncrule_mapping.m:182 writes the STRING
%                    'epoch_bounded_reference' into an INLINE `time_reference`
%                    sub-structure's `kind` field -- a field value, not a class.
%                    The rest are comments.
%
%   And nothing folded it. `did2.convert.resolveSessionAnchors` -- the batch pass
%   that collapses the retiring reference family -- matches exactly two class
%   names and neither is this one:
%
%       $ grep -n "strcmp(anchorClass{k}, 'session_" resolveSessionAnchors.m
%       244:    isRelative = strcmp(anchorClass{k}, 'session_relative_reference');
%       245:    isBounded  = strcmp(anchorClass{k}, 'session_bounded_reference');
%
%   That file's own header already names this gap in its own words
%   (resolveSessionAnchors.m:30-33). It survived because the DID corpus gate does
%   not run the NDI assembler at all: it runs the coarse
%   `did2.convert.resolveDeferredBaths`, which NDI deliberately replaces
%   (stimulusBathToBath: "the LIVE-session counterpart of the coarse
%   did2.convert.resolveDeferredBaths.makeBathVeta"). Two pipelines, one
%   concept, different output classes, and no comparison between them.
%
%   WHAT THE SIGNED DECISION SAYS
%   ---------------------------------------------------------------------
%   DID-schema/schemas/V_eta_time_reference_model_plan.md, line 468:
%
%       TEAM-SIGN-OFF [time_reference]: jess@walthamdatascience.com /
%       2026-08-08 -- 8 classes collapse to absolute_reference +
%       relative_reference; anchor and extent are separated (start + duration,
%       NOT start + end); every value-level `approximate` is deleted; `clock`
%       becomes a bound ontology_term over FOUR terms and the approx_ prefix
%       de-encodes to an explicit clock_tolerance on the root.
%
%   and its migration table (line 195) lists `epoch_bounded_reference` among the
%   six folding into `relative_reference`, ids preserved.
%
%   WHY A BATCH PASS AND NOT A CHANGE AT THE MINT SITE
%   ---------------------------------------------------------------------
%   Exactly the wall `did2.convert.resolveSessionAnchors` documents, one referent
%   over:
%
%     * `relative_reference.relative_to` is REQUIRED (mustBeNonEmpty, team call,
%       fork A of the plan), and the RequiredDependencies strict check is now
%       ARMED, so a blank required edge is a QUARANTINE, not a silent pass.
%     * The referent for an epoch-scoped anchor is the `epoch` document.
%     * `epoch` documents DO NOT EXIST when stimulusBathToBath runs. The
%       assembler is step (1) of ndi.migrate.local's V_eta second pass
%       (local.m, the `resolveDeferred` call); epochMint is step (5) (the
%       `did2.convert.epochMint` call), and this pass is step (5b) between
%       epochMint and the session anchor fold.
%       A find-or-create over the whole corpus cannot be done from one document
%       -- epochMint's own header says why (a per-document mint is a duplicate
%       factory).
%
%   So pass 1 mints the placeholder it CAN fill and this pass upgrades it,
%   which is the shape the plan itself prescribes:
%
%       "A pass-1 migrator knows the epoch STRING (from the inherited `epochid`
%        block) but not the `acquisition_epoch` DOCUMENT id, so it cannot
%        populate `relative_to`. ... The existing schema already hints at the
%        pattern -- `epoch_bounded_reference` carries both the `epochid`
%        superclass and a dependency. So: the string is the pass-1 handle; the
%        edge is the pass-2 resolution."
%              -- V_eta_time_reference_model_plan.md, "Pass 1 vs pass 2"
%
%   THE KEY IS THE PAIR (base.session_id, epoch-id string). NEVER THE STRING.
%   ---------------------------------------------------------------------
%   This pass does NOT re-derive the epoch mapping. It CONSUMES the index
%   epochMint publishes on `result.epoch_mint.epoch_index`, whose rows are
%   {session_id, local_identifier, epoch_document_id} and whose key is already
%   the pair. Re-deriving it here would be a second implementation of a key
%   whose failure mode is silent. Quoted from epochMint's own header, which is
%   where the measurement lives (corpus run 31415147934, `02854c7`,
%   did2.validate.sourceCensus over 6 corpora / 221,827 v1 documents / 0
%   unreadable):
%
%       "an `epochid.epochid` string is REUSED ACROSS SESSIONS (`t00070`
%        restarts in every session directory). In corpus B that is 142 of 149
%        distinct ids -- almost the whole corpus. Grouping on the string alone
%        would FUSE epochs belonging to different sessions, which is a silent
%        merge of recordings from different animals."
%
%   epochMint carries the size of that difference in its own report as
%   `pairs_minus_strings`. I have not run a corpus, so I do not restate the
%   number here; read it off the run. One key, one implementation, and this
%   pass reads that key rather than re-deriving it.
%
%   WHAT IT REFUSES, AND WHY EVERY REFUSAL IS COUNTED
%   ---------------------------------------------------------------------
%   A refusal leaves the document EXACTLY as it is -- still an
%   `epoch_bounded_reference`, still valid, still pointed at by the manipulation
%   that depends on it. That is the state the corpus is green in today, so a
%   refusal cannot regress anything; a guess could. Refusals:
%
%     * no epoch-id string on the body            -> nothing to look up
%     * no `base.session_id`                      -> half a key is not a key
%     * the (session, string) pair is not in the  -> DISCOVERY MODE: a subset
%       index                                        batch need not contain the
%                                                    session document epochMint
%                                                    needs, and absence is not
%                                                    evidence
%     * `epoch_clock` is 'no_time'                -> NO TIMES => NO REFERENCE.
%                                                    The plan's rule. This one
%                                                    should never be seen: the
%                                                    mint site now declines to
%                                                    emit a reference at all in
%                                                    that case. It is counted
%                                                    here so that if it ever IS
%                                                    seen, it is a number.
%     * `epoch_clock` is 'inherited'              -> the plan drops the term
%                                                    because `relative_to`
%                                                    already IS that pointer,
%                                                    and marks the call
%                                                    ABSENCE-BASED. Refuse
%                                                    rather than translate.
%     * any other unrecognised clock string       -> refuse, never map to a
%                                                    neighbour
%
%   THE CLOCK DE-ENCODING (CHANGE 4 of the signed walkthrough)
%   ---------------------------------------------------------------------
%   Nine did_v1 clocktypes become four terms plus an explicit tolerance. The
%   five seconds is in a DOCSTRING in NDI, not in any field:
%
%       +ndi/+time/clocktype.m:21  'approx_utc'  | ... (within 5 seconds)
%       +ndi/+time/clocktype.m:23  'approx_exp_global_time' | ... (within 5s)
%       +ndi/+time/clocktype.m:26  'approx_dev_global_time' | ... (within 5 s)
%
%   so this pass transcribes it, which is what the plan calls for
%   ("transcription, not invention"). `clock_tolerance` goes on the ROOT
%   (`time_reference`), not inside the value -- the team caught that placement
%   error during the walkthrough. NO `source_unit` / `source_value` is written
%   on it: the source wrote a clocktype NAME, not a number in a unit, and
%   filling a source slot would claim a provenance that does not exist (the
%   distance_metadata assumed-shape error).
%
%   THE `relation` IS 'during', AND THAT IS READ, NOT ASSUMED
%   ---------------------------------------------------------------------
%   `epoch_bounded_reference` declares no `relation` field, so there is nothing
%   on the document to read; the class name is the assertion ("bounded by this
%   epoch"). The positive evidence that 'during' is the intended reading is the
%   COARSE COUNTERPART of this very assembler, which does declare one:
%
%       $ grep -n "relation" DID-matlab/src/did/+did2/+convert/resolveDeferredBaths.m
%       188:anchorBody.session_relative_reference = struct('relation', 'during');
%       237:anchorBody.session_relative_reference = struct('relation', 'during');
%
%   resolveDeferredBaths is the pass NDI substitutes stimulusBathToBath for
%   (stimulusBathToBath's "LIVE-session counterpart" comment), building the
%   same bath from the same source with
%   a coarser anchor -- so its relation is this document's relation, measured on
%   the other side of the substitution rather than picked. It maps to
%   `time:intervalDuring` through the same OWL-Time vocabulary
%   resolveSessionAnchors.owlTimeTerm uses, where `during` is also what all 14
%   live v1 emitter call sites carry.
%
%   NO `start` AND NO `duration` ARE WRITTEN. The source document has no
%   offsets, and the plan is explicit that their ABSENCE is the imprecision --
%   a reference carrying invented or NaN metrics is the hollow document
%   did2.validate.silentLoss and the FRAGMENT detector exist to catch.
%
%   ---------------------------------------------------------------------
%   [PLAN, REPORT] = ndi.migrate.internal.epochAnchorFold(MIGRATEDSTRUCTS,
%   EPOCHINDEX)
%
%     MIGRATEDSTRUCTS  cell of migrated document body STRUCTS (the caller does
%                      the toStruct(); this function touches no did2 class, no
%                      schema and no database, so it is unit-testable on plain
%                      structs).
%     EPOCHINDEX       struct array {session_id, local_identifier,
%                      epoch_document_id} -- exactly
%                      `result.epoch_mint.epoch_index`.
%
%     PLAN             struct array, one entry per foldable anchor:
%                      {source_id, body, epoch_document_id, clock,
%                       clock_tolerance_seconds}. `body` is a ready V_eta
%                      `relative_reference` body with base.id PRESERVED.
%     REPORT           the instrument. Every field is defined before a single
%                      document is read, so "did not run" and "ran and found
%                      nothing" are different readings of the same struct.
%
%   See also: ndi.migrate.local, ndi.migrate.internal.stimulusBathToBath,
%   did2.convert.epochMint, did2.convert.resolveSessionAnchors.

arguments
    migratedStructs cell
    epochIndex struct = struct('session_id', {}, 'local_identifier', {}, ...
                               'epoch_document_id', {})
end

% DENOMINATOR FIRST, AND UNCONDITIONALLY.
report = struct( ...
    'documents_inspected',            numel(migratedStructs), ...
    'documents_unreadable',           0, ...
    'epoch_index_rows',               numel(epochIndex), ...
    'epoch_index_pairs_usable',       0, ...
    'anchors_seen',                   0, ...
    'anchors_planned',                0, ...
    'planned_without_clock',          0, ...
    'clock_tolerance_applied',        0, ...
    'refused_no_epoch_string',        0, ...
    'refused_no_session_id',          0, ...
    'refused_no_epoch_document',      0, ...
    'refused_clock_no_time',          0, ...
    'refused_clock_inherited',        0, ...
    'refused_clock_unknown',          0, ...
    'refused_total',                  0, ...
    'changed',                        false);

plan = struct('source_id', {}, 'body', {}, 'epoch_document_id', {}, ...
    'clock', {}, 'clock_tolerance_seconds', {});

if isempty(migratedStructs)
    return;
end

% --- index the epochs by the PAIR -----------------------------------------
% Built from epochMint's own rows, so the key here cannot drift from the key
% that minted them.
epochByPair = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(epochIndex)
    sid = charOf(epochIndex(k), 'session_id');
    lid = charOf(epochIndex(k), 'local_identifier');
    epochDocumentId = charOf(epochIndex(k), 'epoch_document_id');
    if isempty(sid) || isempty(lid) || isempty(epochDocumentId)
        continue;   % half a key names no epoch
    end
    key = pairKey(sid, lid);
    if isKey(epochByPair, key)
        continue;
    end
    epochByPair(key) = epochDocumentId;
end
report.epoch_index_pairs_usable = double(epochByPair.Count);

% --- fold every anchor that resolves honestly ------------------------------
for k = 1:numel(migratedStructs)
    b = migratedStructs{k};
    if ~isstruct(b) || ~isscalar(b)
        report.documents_unreadable = report.documents_unreadable + 1;
        continue;
    end
    if ~strcmp(classNameOf(b), 'epoch_bounded_reference')
        continue;
    end
    report.anchors_seen = report.anchors_seen + 1;

    epochString = epochStringOf(b);
    if isempty(epochString)
        report.refused_no_epoch_string = report.refused_no_epoch_string + 1;
        continue;
    end
    sessionId = baseField(b, 'session_id');
    if isempty(sessionId)
        report.refused_no_session_id = report.refused_no_session_id + 1;
        continue;
    end
    key = pairKey(sessionId, epochString);
    if ~isKey(epochByPair, key)
        % DISCOVERY MODE, or a session with no `session` document for epochMint
        % to anchor to. Absence is not evidence; leave the anchor alone.
        report.refused_no_epoch_document = report.refused_no_epoch_document + 1;
        continue;
    end

    [clockName, toleranceSeconds, verdict] = clockTerm(epochClockOf(b));
    switch verdict
        case 'no_time'
            report.refused_clock_no_time = report.refused_clock_no_time + 1;
            continue;
        case 'inherited'
            report.refused_clock_inherited = report.refused_clock_inherited + 1;
            continue;
        case 'unknown'
            report.refused_clock_unknown = report.refused_clock_unknown + 1;
            continue;
    end

    epochDocId = epochByPair(key);
    [body, hadClock] = rebuildAsRelativeReference(b, epochDocId, clockName, ...
        toleranceSeconds);
    if ~hadClock
        report.planned_without_clock = report.planned_without_clock + 1;
    end
    if toleranceSeconds > 0
        report.clock_tolerance_applied = report.clock_tolerance_applied + 1;
    end

    plan(end+1) = struct( ...
        'source_id',               baseField(b, 'id'), ...
        'body',                    body, ...
        'epoch_document_id',       epochDocId, ...
        'clock',                   clockName, ...
        'clock_tolerance_seconds', toleranceSeconds); %#ok<AGROW>
end

report.anchors_planned = numel(plan);
report.refused_total = report.refused_no_epoch_string ...
    + report.refused_no_session_id ...
    + report.refused_no_epoch_document ...
    + report.refused_clock_no_time ...
    + report.refused_clock_inherited ...
    + report.refused_clock_unknown;
report.changed = report.anchors_planned > 0;
end

% ===================== the rebuild ========================================

function [b, hadClock] = rebuildAsRelativeReference(b, epochDocId, clockName, ...
    toleranceSeconds)
%REBUILDASRELATIVEREFERENCE The retired body -> a V_eta relative_reference.
%   THE base.id IS NOT TOUCHED, so every `time_reference_#` edge pointing at
%   this document keeps resolving -- the same guarantee resolveSessionAnchors
%   makes, and the reason the calculator fold produced 0 orphans.

b.document_class = struct( ...
    'class_name',     'relative_reference', ...
    'class_version',  '2.0.0', ...
    'superclasses',   struct('class_name', 'time_reference', ...
                             'class_version', '4.0.0'), ...
    'schema_version', 'V_eta');

% The `element_id` edge is REPLACED, not kept: `relative_reference` declares
% exactly one dependency and an undeclared edge trips the strict-fields check
% (+did2/+schema/cache.m). The stimulator is not lost -- stimulusBathToBath now
% carries it on the manipulation as `instrument_id` (T7), which is where the
% instrument of an interaction belongs and which does not depend on this fold
% running.
b.depends_on = struct('name', 'relative_to', 'value', epochDocId);

value = struct('relation', struct('node', 'time:intervalDuring', ...
                                  'name', 'intervalDuring'));
hadClock = ~isempty(clockName);
if hadClock
    % Nodes are STAGED EMPTY in the schema's own binding (`did_clocktype`): no
    % NDIC identifier can be assigned from any repository in scope, and the
    % schema says so in its own documentation. Writing a made-up CURIE here
    % would be worse than leaving it blank.
    value.clock = struct('node', '', 'name', clockName);
end

% The old class block and the `epochid` mixin both go: the string was the pass-1
% handle and the edge is its resolution, so keeping both would store one fact
% twice with nothing saying which is authoritative.
if isfield(b, 'epoch_bounded_reference')
    b = rmfield(b, 'epoch_bounded_reference');
end
if isfield(b, 'epochid')
    b = rmfield(b, 'epochid');
end
% The deprecated root flag goes with it (CHANGE 2: every value-level
% `approximate` is deleted; the absence IS the imprecision).
if isfield(b, 'time_reference')
    b = rmfield(b, 'time_reference');
end
if toleranceSeconds > 0
    % Back onto the ROOT, carrying only what the source actually stated.
    b.time_reference = struct('clock_tolerance', ...
        struct('seconds', toleranceSeconds));
end

b.relative_reference = struct('value', value);
end

% ===================== vocabulary =========================================

function [clockName, toleranceSeconds, verdict] = clockTerm(raw)
%CLOCKTERM did_v1's nine clocktypes -> the four signed terms + a tolerance.
%   CHANGE 4 of the signed walkthrough. The `approx_` prefix is mode-in-a-name
%   (T13) hiding a NUMBER in a docstring (T14); it de-encodes to data rather
%   than folding into a boolean, which would lose the five seconds.
verdict = 'ok';
toleranceSeconds = 0;
clockName = '';
raw = char(raw);
if isempty(raw)
    % epoch_clock is mustBeNonEmpty on the source class, so a validated document
    % cannot get here. If one does, fold WITHOUT a clock rather than refuse:
    % there is no timeline stated, and inventing one would be the invented-field
    % pattern. Counted as planned_without_clock. Handled BEFORE the switch --
    % switching on a 0x0 char is a shape this code should not have to rely on.
    return;
end
switch raw
    case {'utc', 'dev_local_time', 'dev_global_time', 'exp_global_time'}
        clockName = raw;
    case 'approx_utc'
        clockName = 'utc';              toleranceSeconds = 5;
    case 'approx_dev_global_time'
        clockName = 'dev_global_time';  toleranceSeconds = 5;
    case 'approx_exp_global_time'
        clockName = 'exp_global_time';  toleranceSeconds = 5;
    case 'no_time'
        verdict = 'no_time';
    case 'inherited'
        verdict = 'inherited';
    otherwise
        verdict = 'unknown';
end
end

% ===================== body helpers =======================================

function key = pairKey(sessionId, epochString)
%PAIRKEY The mint key, length-prefixed so no separator can be forged.
%   CHARACTER-FOR-CHARACTER did2.convert.epochMint's own pairKey (its line 535).
%   The map built here is local, so it need only be self-consistent -- but a key
%   that differs from the minting key by even a separator is exactly the kind of
%   near-miss that reads as "the epoch is missing" forever, so it is copied
%   rather than reinvented. epochMint's note, which applies unchanged:
%   `[sessionId '|' epochString]` would let a session id ending in '|' collide
%   with another pair; cheap to prevent, expensive to notice.
key = sprintf('%d:%s|%s', numel(sessionId), sessionId, epochString);
end

function name = classNameOf(b)
name = '';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    name = char(b.document_class.class_name);
end
end

function v = baseField(b, name)
v = '';
if isfield(b, 'base') && isstruct(b.base) && isfield(b.base, name)
    raw = b.base.(name);
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        v = char(raw);
    end
end
end

function e = epochStringOf(b)
% The did_v1 `epochid` mixin, in both spellings the rest of this tree accepts.
% NOT a wider read: this pass only ever sees documents IT put the block on.
e = '';
for blk = {'epochid', 'epoch_id'}
    if ~isfield(b, blk{1}) || ~isstruct(b.(blk{1}))
        continue;
    end
    for f = {'epochid', 'epoch_id', 'epochId'}
        if isfield(b.(blk{1}), f{1})
            raw = b.(blk{1}).(f{1});
            if (ischar(raw) || (isstring(raw) && isscalar(raw))) && ~isempty(raw)
                e = char(raw);
                return;
            end
        end
    end
end
end

function c = epochClockOf(b)
c = '';
if isfield(b, 'epoch_bounded_reference') ...
        && isstruct(b.epoch_bounded_reference) ...
        && isfield(b.epoch_bounded_reference, 'epoch_clock')
    raw = b.epoch_bounded_reference.epoch_clock;
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        c = char(raw);
    end
end
end

function v = charOf(s, name)
v = '';
if isstruct(s) && isfield(s, name)
    raw = s.(name);
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        v = char(raw);
    end
end
end
