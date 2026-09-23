function [unit_ids, unit_labels] = labels(kdir, options)
% NDI.FUN.PROBE.IMPORT.KIASORT.LABELS - list the units in a KIASORT sort and their labels
%
% [UNIT_IDS, UNIT_LABELS] = NDI.FUN.PROBE.IMPORT.KIASORT.LABELS(KDIR, ...)
%
% Reads the KIASORT output folder KDIR and returns the list of cross-channel unit
% ids (UNIT_IDS, a numeric vector) and a parallel string array of curation labels
% (UNIT_LABELS).
%
% Unlike Kilosort/Phy, a plain KIASORT sort does not tag each unit as "good"/"mua"/
% "noise": every cross-channel unit it emits is a candidate single unit. This
% function therefore assigns every unit the label "good" by default, so the
% quality-label filter in ndi.fun.probe.import.kiasort.probe (whose default is
% ["good"]) imports all of them. This keeps the API parallel to
% ndi.fun.probe.import.kilosort.labels; users who curate KIASORT output can extend
% this to read their own per-unit tags. (Isolation-based quality is available in
% R.unit_stats for a future quality mapping.)
%
% The unit ids are taken from the per-unit statistics (crossChannelStats.
% unified_labels.label) when available, otherwise from the distinct values of the
% per-spike unit assignments in unifiedLabels.h5.
%
% Name/value pairs:
%   curated (false)      - Prefer the '_curated' KIASORT output when present.
%   default_label ("good")- Label assigned to every unit.
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.PROBE, NDI.FUN.PROBE.IMPORT.KIASORT.RESULTS

    arguments
        kdir (1,:) char
        options.curated (1,1) logical = false
        options.default_label (1,1) string = "good"
    end

    unit_stats = ndi.fun.probe.import.kiasort.unitstats(kdir, ternary(options.curated,'_curated',''));

    if ~isempty(unit_stats) && ~isempty(unit_stats.label),
        unit_ids = double(unit_stats.label(:));
    else,
        % fall back to the distinct unit ids present in the per-spike output
        R = ndi.fun.probe.import.kiasort.results(kdir, 'curated', options.curated, 'need_stats', false);
        unit_ids = unique(R.spike_units);
        unit_ids = unit_ids(:);
    end;

    unit_labels = repmat(options.default_label, numel(unit_ids), 1);

end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end;
end
