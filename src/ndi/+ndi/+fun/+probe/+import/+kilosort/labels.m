function [cluster_ids, cluster_labels] = labels(kdir)
% NDI.FUN.PROBE.IMPORT.KILOSORT.LABELS - read curated cluster labels from kilosort/Phy output
%
% [CLUSTER_IDS, CLUSTER_LABELS] = NDI.FUN.PROBE.IMPORT.KILOSORT.LABELS(KDIR)
%
% Reads the per-cluster curation labels from a kilosort/Phy output directory KDIR.
% Looks for (in order of preference) 'cluster_group.tsv' (manual Phy curation),
% 'cluster_KSLabel.tsv' (automatic Kilosort labels), or 'cluster_info.tsv'.
%
% Returns CLUSTER_IDS, a numeric vector of cluster ids, and CLUSTER_LABELS, a
% string array of the corresponding labels (e.g. "good", "mua", "noise", or any
% custom tag the user applied during curation).
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE

    candidates = {'cluster_group.tsv', 'cluster_KSLabel.tsv', 'cluster_info.tsv'};
    label_columns = {'group', 'KSLabel', 'group'};

    cluster_ids = [];
    cluster_labels = strings(0,1);

    for c=1:numel(candidates),
        f = fullfile(kdir, candidates{c});
        if ~isfile(f),
            continue;
        end;
        T = readtable(f, 'FileType','text', 'Delimiter','\t', ...
            'ReadVariableNames', true);
        vn = T.Properties.VariableNames;
        % the id column is named 'cluster_id' (or 'id' in some Phy versions)
        idcol = find(strcmpi(vn,'cluster_id') | strcmpi(vn,'id'), 1);
        labcol = find(strcmpi(vn, label_columns{c}), 1);
        if isempty(labcol), % fall back to any column literally called 'group'
            labcol = find(strcmpi(vn,'group'),1);
        end;
        if isempty(idcol) || isempty(labcol),
            continue;
        end;
        cluster_ids = double(T{:, idcol});
        cluster_labels = string(T{:, labcol});
        return;
    end;

    error(['No cluster label file (cluster_group.tsv, cluster_KSLabel.tsv, or ' ...
        'cluster_info.tsv) found in ' kdir '.']);

end
