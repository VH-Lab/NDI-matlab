function [info, summary] = getInfo(S, probe, options)
% NDI.FUN.PROBE.IMPORT.KILOSORT.GETINFO - summarize the kilosort/phy output for a probe
%
% [INFO, SUMMARY] = NDI.FUN.PROBE.IMPORT.KILOSORT.GETINFO(S, PROBE, ...)
%
% Reads the curated Kilosort/Phy output directory for the probe PROBE in the
% ndi.session S and returns a summary of what is there (without importing
% anything or touching the database). This is useful for inspecting a sort
% before calling NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE.
%
% The directory is located the same way as the importer:
%
%       [S.path]/[kilosort_dir]/[probe_elementstring]/[subdir]/
%
% INFO is a structure with fields:
%   directory          - the directory that was read
%   num_clusters       - number of curated clusters
%   cluster_ids        - vector of cluster ids
%   cluster_labels     - string array of the label/tag for each cluster
%   unique_tags        - string array of the distinct labels/tags present
%   tag_counts         - number of clusters carrying each unique tag (parallel
%                          to unique_tags)
%   num_spikes_total   - total number of spikes across all clusters
%   num_spikes         - vector of spike counts per cluster (parallel to cluster_ids)
%   would_import       - logical vector, true for clusters whose tag is in
%                          quality_labels (i.e. would be imported by default)
%   num_would_import   - number of clusters that would be imported
%   num_templates      - number of Kilosort templates (NaN if templates absent)
%   num_channels       - number of channels in the templates (NaN if absent)
%   samples_per_template - samples per template waveform (NaN if absent)
%
% SUMMARY is a multiline character array giving a human-readable version of INFO.
%
% Name/value pairs (defaults match NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE):
% ---------------------------------------------------------------------------------
% | Parameter (default)            | Description                                   |
% |--------------------------------|-----------------------------------------------|
% | kilosort_dir ('kilosort')      | Name of the directory holding kilosort output |
% | subdir ('kilosort_output')     | Subfolder within the probe's directory        |
% | noSubFolder (false)            | If true, read directly from the probe's dir   |
% | quality_labels (["good" "mua"])| Labels that would be imported (for would_import)|
% ---------------------------------------------------------------------------------
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    [info, summary] = ndi.fun.probe.import.kilosort.getInfo(S, p{1});
%    disp(summary);
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE

    arguments
        S
        probe
        options.kilosort_dir (1,:) char = 'kilosort'
        options.subdir (1,:) char = 'kilosort_output'
        options.noSubFolder (1,1) logical = false
        options.quality_labels (1,:) string = ["good" "mua"]
    end

    % Step 1: locate the kilosort output directory (same logic as the importer)
    elestr = probe.elementstring();
    elestr(elestr==' ') = '_';
    subdir = options.subdir;
    if options.noSubFolder,
        subdir = '';
    end;
    kdir = fullfile(S.path, options.kilosort_dir, elestr, subdir);

    if ~isfolder(kdir),
        error(['Kilosort directory not found: ' kdir '.']);
    end;

    spike_times_file = fullfile(kdir,'spike_times.npy');
    spike_clusters_file = fullfile(kdir,'spike_clusters.npy');
    if ~isfile(spike_times_file) || ~isfile(spike_clusters_file),
        error(['Expected curated files spike_times.npy and spike_clusters.npy in ' kdir '.']);
    end;

    % Step 2: read the curated output
    spike_clusters = double(ndi.util.readNPY(spike_clusters_file));
    [cluster_ids, cluster_labels] = ndi.fun.probe.import.kilosort.labels(kdir);

    cluster_ids = cluster_ids(:);
    cluster_labels = cluster_labels(:);
    nC = numel(cluster_ids);

    % Step 3: spike counts per cluster
    num_spikes = zeros(nC,1);
    for i=1:nC,
        num_spikes(i) = sum(spike_clusters==cluster_ids(i));
    end;

    % Step 4: unique tags and their cluster counts
    [unique_tags, ~, ic] = unique(cluster_labels);
    tag_counts = accumarray(ic(:), 1);

    % Step 5: which clusters would be imported under the quality filter
    want = lower(string(options.quality_labels));
    would_import = false(nC,1);
    for i=1:nC,
        would_import(i) = any(want==lower(string(cluster_labels(i))));
    end;

    % Step 6: template dimensions, if templates are present
    num_templates = NaN; num_channels = NaN; samples_per_template = NaN;
    tfile = fullfile(kdir,'templates.npy');
    if isfile(tfile),
        templates = ndi.util.readNPY(tfile);
        sz = size(templates);
        num_templates = sz(1);
        if numel(sz)>=2, samples_per_template = sz(2); end;
        if numel(sz)>=3, num_channels = sz(3); end;
    end;

    % Step 7: assemble the info structure
    info = struct();
    info.directory = kdir;
    info.num_clusters = nC;
    info.cluster_ids = cluster_ids;
    info.cluster_labels = cluster_labels;
    info.unique_tags = unique_tags(:);
    info.tag_counts = tag_counts(:);
    info.num_spikes_total = sum(num_spikes);
    info.num_spikes = num_spikes;
    info.would_import = would_import;
    info.num_would_import = sum(would_import);
    info.num_templates = num_templates;
    info.num_channels = num_channels;
    info.samples_per_template = samples_per_template;

    % Step 8: build the multiline character summary
    nl = newline;
    lines = {};
    lines{end+1} = ['Kilosort/Phy summary for probe ''' probe.elementstring() ''''];
    lines{end+1} = ['  Directory:        ' kdir];
    lines{end+1} = ['  Clusters:         ' int2str(nC)];
    lines{end+1} = ['  Total spikes:     ' int2str(info.num_spikes_total)];
    if nC>0,
        lines{end+1} = ['  Spikes/cluster:   min ' int2str(min(num_spikes)) ...
            ', median ' int2str(round(median(num_spikes))) ...
            ', max ' int2str(max(num_spikes))];
    end;
    lines{end+1} = '  Tags:';
    for i=1:numel(unique_tags),
        lines{end+1} = ['     ' char(unique_tags(i)) ': ' int2str(tag_counts(i)) ' cluster(s)'];
    end;
    lines{end+1} = ['  Would import (' char(strjoin(options.quality_labels,', ')) '): ' ...
        int2str(info.num_would_import) ' of ' int2str(nC) ' cluster(s)'];
    if ~isnan(num_templates),
        lines{end+1} = ['  Templates:        ' int2str(num_templates) ' templates, ' ...
            num2str(num_channels) ' channels, ' num2str(samples_per_template) ' samples each'];
    else,
        lines{end+1} = '  Templates:        (templates.npy not present)';
    end;

    summary = strjoin(lines, nl);

end
