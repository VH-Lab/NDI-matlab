function lines = ensembleGateReport(report)
%ENSEMBLEGATEREPORT Render the ensemble second pass's verify-before-delete gate.
%   LINES = ENSEMBLEGATEREPORT(REPORT) turns the struct returned by
%   ndi.migrate.internal.ensembleMembership into a cellstr, denominator first
%   and unconditionally. Pure formatting: it reads nothing, computes no new
%   fact, and NEVER re-derives the verdict -- `verify_before_delete_clear` is
%   printed as the assembler computed it, with the reasons alongside.
%
%   WHY THIS FILE EXISTS. The gate is `V_eta_ensemble_plan.md` deferred build
%   task 4 -- the data-loss gate that must read clear before the combined
%   marked-point-process bytes may be dropped. ndi.migrate.internal.
%   ensembleMembership has MEASURED it since it was written. Nothing rendered
%   it. Measured 2026-08-11 across all three repositories:
%
%     $ grep -rn "verify_before_delete\|neuron_trains_\|member_of_minted" \
%           NDI-matlab DID-matlab DID-schema | sed 's/:.*//' | sort | uniq -c
%          19 NDI-matlab/src/ndi/+ndi/+migrate/+internal/ensembleMembership.m
%           2 NDI-matlab/src/ndi/+ndi/+migrate/local.m          <- docstring only
%          32 NDI-matlab/tests/.../TestEnsembleMembership.m
%
%   i.e. the assembler, its own prose, and its own tests. `local.m` stores the
%   report at `result.secondPass.ensembleMembership` and `printSummary` prints
%   five lines, none of them from any second pass. A gate that runs over a
%   whole corpus and reaches no log is the failure DID-matlab's census digest
%   armed a non-zero exit against ("*** MEASURED BY NOTHING"), arriving on the
%   NDI side where no such gate existed.
%
%   THREE PROPERTIES ARE LOAD-BEARING, not presentation:
%
%   1. ABSENT IS NOT ZERO. A counter this renderer cannot find prints the word
%      ABSENT. A report whose shape drifts must read as unreadable, never as a
%      corpus full of zeroes -- that substitution is how "the instrument broke"
%      becomes "the data is clean".
%
%   2. THE THREE TRAIN BUCKETS ARE NEVER SUMMED, and no total is offered. The
%      assembler's header says why: "no train anywhere" and "trains exist but
%      not under this epoch id" are different findings, and collapsing them
%      makes "the data is not there" indistinguishable from "the data is there
%      and I looked in the wrong place" -- on a gate that authorises deleting
%      the only surviving copy.
%
%   3. NOT CLEAR ALWAYS CARRIES ITS REASON, and "nothing was inspected" is one
%      of the reasons. An empty corpus already renders NOT CLEAR because the
%      assembler requires `ensemble_maps_used > 0`; this printer says so in
%      words, so a run with no ensembles cannot be read as a clearance that
%      merely happened to be silent.
%
%   Nothing here deletes anything and no option enables deletion. A CLEAR
%   verdict is a MEASUREMENT; acting on it is a separate, team-gated build
%   (`V_eta_ensemble_plan.md` migration constraint 3).
%
%   See also: ndi.migrate.internal.ensembleMembership, ndi.migrate.local,
%     DID-schema schemas/V_eta_ensemble_plan.md.

if ~isstruct(report) || ~isscalar(report)
    lines = { ...
        '  ensemble second pass -- DENOMINATOR: NONE. The pass returned no report.'; ...
        '    NOT MEASURED. This is not a clearance: nothing was inspected, so the'; ...
        '    verify-before-delete gate has no verdict at all.'};
    return;
end

lines = {};
lines{end+1,1} = sprintf(['  ensemble second pass -- DENOMINATOR: %s document(s) inspected, ' ...
    '%s ensemble map(s) seen'], countOf(report, 'documents_inspected'), ...
    countOf(report, 'ensemble_maps_seen'));
lines{end+1,1} = sprintf(['      a map document is PER EPOCH: %s distinct ensemble(s), ' ...
    '%s distinct epoch(s)'], countOf(report, 'distinct_ensembles_seen'), ...
    countOf(report, 'distinct_epochs_seen'));
lines{end+1,1} = sprintf('    maps used %s   (no group subject %s, no neuron edges %s)', ...
    countOf(report, 'ensemble_maps_used'), countOf(report, 'ensemble_maps_no_group'), ...
    countOf(report, 'ensemble_maps_no_neurons'));
lines{end+1,1} = sprintf('    neuron edges: seen %s, resolved %s, stranded %s', ...
    countOf(report, 'neuron_edges_seen'), countOf(report, 'neuron_edges_resolved'), ...
    countOf(report, 'neuron_edges_stranded'));
lines{end+1,1} = sprintf('    minted: member_of %s, derived_from %s', ...
    countOf(report, 'member_of_minted'), countOf(report, 'derived_from_minted'));
lines{end+1,1} = sprintf('    cache carriers: seen %s, resolved %s', ...
    countOf(report, 'cache_carriers_seen'), countOf(report, 'cache_carriers_resolved'));

% --- epoch scoping. The signed model REQUIRES the roster to be per-epoch, so
% an unscoped edge is a partial result and each reason has its own remedy.
lines{end+1,1} = sprintf('    epoch scoping: resolver wired %s   edges scoped %s, unscoped %s', ...
    yesNoOf(report, 'epoch_scope_available'), countOf(report, 'epoch_scoped_edges'), ...
    countOf(report, 'unscoped_edges'));
lines{end+1,1} = sprintf(['      maps scoped %s; unscoped -- no resolver %s, ' ...
    'no epoch string %s, epoch unresolved %s'], ...
    countOf(report, 'maps_epoch_scoped'), countOf(report, 'maps_unscoped_no_resolver'), ...
    countOf(report, 'maps_unscoped_no_epoch_string'), ...
    countOf(report, 'maps_unscoped_epoch_unresolved'));
if isfield(report, 'epoch_index_rows') || isfield(report, 'epoch_index_pairs_usable')
    % Added by the caller (local.m resolveEnsembleMembership) from epochMint's
    % own index. Rendered only when present so this printer stays usable on a
    % bare assembler report.
    lines{end+1,1} = sprintf('      epochMint index: %s row(s), %s usable (session_id, epoch) pair(s)', ...
        countOf(report, 'epoch_index_rows'), countOf(report, 'epoch_index_pairs_usable'));
end

% --- the gate itself ------------------------------------------------------
lines{end+1,1} = '    TRAINS -- three buckets, DELIBERATELY NOT SUMMED (see header):';
lines{end+1,1} = sprintf('      present under this map''s epochid   %s', ...
    countOf(report, 'neuron_trains_present_this_epoch'));
lines{end+1,1} = sprintf('      train(s) exist, other epochid only  %s', ...
    countOf(report, 'neuron_trains_other_epoch_only'));
lines{end+1,1} = sprintf('      no train document at all            %s', ...
    countOf(report, 'neuron_trains_missing_entirely'));
lines{end+1,1} = sprintf(['      instrument denominator: %s epoch document(s) seen, ' ...
    '%s carrying a binary'], countOf(report, 'train_documents_seen'), ...
    countOf(report, 'train_documents_with_binary'));

reasons = notClearReasons(report);
lines{end+1,1} = sprintf('    VERIFY-BEFORE-DELETE: %s', verdictOf(report));
for k = 1:numel(reasons)
    lines{end+1,1} = sprintf('      because: %s', reasons{k}); %#ok<AGROW>
end
lines{end+1,1} = ['      (a MEASUREMENT. Nothing here deletes bytes and no option ' ...
    'enables deletion.)'];
end

% ===================== formatting helpers ==============================

function s = countOf(report, name)
%COUNTOF The named scalar counter, or the word ABSENT. NEVER 0 for a missing
%   field -- a report whose shape drifted must not read as a clean corpus.
s = 'ABSENT';
if isfield(report, name)
    v = report.(name);
    if (isnumeric(v) || islogical(v)) && isscalar(v)
        s = sprintf('%d', double(v));
    end
end
end

function s = yesNoOf(report, name)
s = 'ABSENT';
if isfield(report, name)
    v = report.(name);
    if (isnumeric(v) || islogical(v)) && isscalar(v)
        if v; s = 'yes'; else; s = 'no'; end
    end
end
end

function t = verdictOf(report)
%VERDICTOF The assembler's own verdict, never re-derived here.
t = 'ABSENT -- no verdict was computed, which is NOT a clearance';
if isfield(report, 'verify_before_delete_clear')
    v = report.verify_before_delete_clear;
    if (isnumeric(v) || islogical(v)) && isscalar(v)
        if v
            t = 'CLEAR';
        else
            t = 'NOT CLEAR';
        end
    end
end
end

function reasons = notClearReasons(report)
%NOTCLEARREASONS Why the gate did not clear, in the assembler's own terms.
%   Returns {} when the verdict is CLEAR. Every condition the assembler ANDs
%   into `verify_before_delete_clear` appears here, plus the instrument
%   self-check its header demands.
reasons = {};
if isfield(report, 'verify_before_delete_clear')
    v = report.verify_before_delete_clear;
    if (isnumeric(v) || islogical(v)) && isscalar(v) && v
        return;   % CLEAR: the reasons list is empty by construction
    end
end

n = numOf(report, 'ensemble_maps_used');
if isnan(n)
    reasons{end+1} = 'ensemble_maps_used is ABSENT from the report';
elseif n == 0
    reasons{end+1} = ['nothing was inspected -- 0 ensemble map document(s) used. ' ...
        'This zero is UNTESTED, not clean'];
end

n = numOf(report, 'neuron_edges_resolved');
if isnan(n)
    reasons{end+1} = 'neuron_edges_resolved is ABSENT from the report';
elseif n == 0 && numOf(report, 'ensemble_maps_used') > 0
    reasons{end+1} = '0 neuron edge(s) resolved to a migrated subject';
end

n = numOf(report, 'neuron_edges_stranded');
if n > 0
    reasons{end+1} = sprintf(['%d neuron edge(s) name an id that is not a migrated ' ...
        'subject (stranded)'], n);
end

n = numOf(report, 'neuron_trains_missing_entirely');
if n > 0
    reasons{end+1} = sprintf(['%d neuron(s) have NO train document at all -- the ' ...
        'combined binary may be the only surviving copy'], n);
end

n = numOf(report, 'neuron_trains_other_epoch_only');
if n > 0
    reasons{end+1} = sprintf(['%d neuron(s) have train(s) filed under a DIFFERENT ' ...
        'epochid than this map''s'], n);
end

% The instrument self-check the assembler's header asks for by name: if the
% batch is full of epoch documents and none carries bytes, every "missing
% train" above is an artefact of this instrument, not a fact about the corpus.
seen  = numOf(report, 'train_documents_seen');
bytes = numOf(report, 'train_documents_with_binary');
if seen > 0 && bytes == 0
    reasons{end+1} = sprintf(['INSTRUMENT WARNING: %d epoch document(s) seen and 0 ' ...
        'carrying a binary -- read every train count above as a property of the ' ...
        'query, not of the corpus'], seen);
end
end

function v = numOf(report, name)
%NUMOF The named scalar as a double, or NaN when it is absent or not scalar.
v = NaN;
if isfield(report, name)
    x = report.(name);
    if (isnumeric(x) || islogical(x)) && isscalar(x)
        v = double(x);
    end
end
end
