function nRemoved = resolveExistingNeurons(S, probe, clusterDocs, options)
% NDI.FUN.PROBE.IMPORT.RESOLVEEXISTINGNEURONS - find neurons left by an earlier import and ask what to do
%
% NREMOVED = NDI.FUN.PROBE.IMPORT.RESOLVEEXISTINGNEURONS(S, PROBE, CLUSTERDOCS, ...)
%
% The spike-sorting importers (ndi.fun.probe.import.kilosort.probe,
% ndi.fun.probe.import.jrclust.probe, ndi.fun.probe.import.kiasort.probe) name each
% imported neuron [PROBE.name '_' PROBE.reference '_' CLUSTER_ID] and find a previous
% import through its cluster document (kilosort_clusters, jrclust_clusters or
% kiasort_clusters), which depends on PROBE's id. Neurons whose cluster document is
% not found that way - for example because PROBE's id changed between imports, or an
% earlier import was interrupted part-way - are not removed when the sort is imported
% again, so the session ends up with two 'element' documents with the same name and
% reference. ndi.element/load_element_doc then errors with "More than one document
% matches the ELEMENT definition" whenever either neuron is used.
%
% This function looks for such neurons before an import writes anything. CLUSTERDOCS
% is a cell array of the cluster documents the importer already found for PROBE;
% neurons that belong to them are left to the importer and are not reported here. The
% neurons it finds are any 'ndi.neuron' element in S with PROBE's reference whose name
% has the form [PROBE.name '_' PROBE.reference '_' <integer>].
%
% If any are found, what happens depends on the 'ExistingNeurons' option:
%   'ask'    (default) list them and ask at the command line whether to remove them
%            and continue, or to cancel. When MATLAB is running without a user
%            (matlab -batch), this behaves like 'error'.
%   'remove' remove them (and their epoch, neuron_extracellular and orphaned cluster
%            documents) without asking.
%   'error'  stop with error ndi:fun:probe:import:existingNeurons.
% Cancelling at the prompt also raises ndi:fun:probe:import:existingNeurons, so the
% database is left unchanged.
%
% NREMOVED is the number of neuron elements removed.
%
% This function takes name/value pairs that modify its operation:
% |--------------------------|-----------------------------------------------------|
% | ExistingNeurons ('ask')  | 'ask', 'remove' or 'error' (see above)              |
% | dryRun (false)           | Only report what was found; change nothing.         |
% | verbose (true)           | Report what was found and done.                     |
% | importer ('import')      | Name of the calling importer, used in messages.     |
% |--------------------------|-----------------------------------------------------|
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE, NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE,
%   NDI.FUN.PROBE.IMPORT.KIASORT.PROBE

    arguments
        S
        probe
        clusterDocs = {}
        options.ExistingNeurons (1,:) char {mustBeMember(options.ExistingNeurons,{'ask','remove','error'})} = 'ask'
        options.dryRun (1,1) logical = false
        options.verbose (1,1) logical = true
        options.importer (1,:) char = 'import'
    end

    nRemoved = 0;
    if ~iscell(clusterDocs), clusterDocs = {clusterDocs}; end;

    % 1) every ndi.neuron in this session with the probe's reference and an importer-style name

    q = ndi.query('base.session_id','exact_string',S.id(),'') & ...
        ndi.query('','isa','element','') & ...
        ndi.query('element.ndi_element_class','exact_string','ndi.neuron','') & ...
        ndi.query('element.reference','exact_number',probe.reference,'');
    candidates = S.database_search(q);

    namePattern = ['^' regexptranslate('escape', [probe.name '_' int2str(probe.reference) '_']) '\d+$'];
    keep = false(1,numel(candidates));
    for i=1:numel(candidates),
        keep(i) = ~isempty(regexp(candidates{i}.document_properties.element.name, namePattern, 'once'));
    end;
    candidates = candidates(keep);
    if isempty(candidates), return; end;

    % 2) leave out the neurons that belong to the cluster documents the importer found

    ownedIds = {};
    for i=1:numel(clusterDocs),
        qn = ndi.query('','isa','neuron_extracellular','') & ...
            ndi.query('','depends_on','spike_clusters_id', clusterDocs{i}.id());
        nd = S.database_search(qn);
        for j=1:numel(nd),
            ownedIds{end+1} = nd{j}.dependency_value('element_id', 'ErrorIfNotFound', 0); %#ok<AGROW>
        end;
    end;
    candidateIds = cellfun(@(d) d.id(), candidates, 'UniformOutput', false);
    strays = candidates(~ismember(candidateIds, ownedIds));
    if isempty(strays), return; end;

    strayNames = cellfun(@(d) d.document_properties.element.name, strays, 'UniformOutput', false);
    nDuplicated = numel(strayNames) - numel(unique(strayNames));

    % 3) describe them

    nShow = min(numel(strays), 10);
    listing = sprintf('    %s\n', strayNames{1:nShow});
    if numel(strays) > nShow,
        listing = [listing sprintf('    ... and %d more\n', numel(strays)-nShow)];
    end;
    msg = sprintf(['%s: found %d neuron element(s) for probe %s that were made by an earlier ' ...
        'import of this probe but are not linked to its current cluster document:\n%s'], ...
        options.importer, numel(strays), probe.elementstring(), listing);
    if nDuplicated > 0,
        msg = [msg sprintf(['  %d of these names appear more than once already, which makes ' ...
            'ndi.element/load_element_doc fail with "More than one document matches the ' ...
            'ELEMENT definition".\n'], nDuplicated)];
    end;
    msg = [msg sprintf(['  Importing again without removing them would create a second neuron ' ...
        'with the same name for each one.\n'])];

    if options.dryRun,
        disp(['[dry run] ' msg '[dry run] A real run would ' ...
            describeAction(options.ExistingNeurons) ' (option ''ExistingNeurons'').']);
        return;
    end;

    % 4) decide

    mode = options.ExistingNeurons;
    if strcmp(mode,'ask') && ~isInteractive(),
        mode = 'error';
    end;

    switch mode,
        case 'error',
            error('ndi:fun:probe:import:existingNeurons', '%s%s', msg, ...
                ['  Pass ''ExistingNeurons'',''remove'' to remove them and import, or remove them ' ...
                'yourself with ndi.fun.probe.import.resolveExistingNeurons.']);
        case 'ask',
            disp(msg);
            answer = input('  Remove them and continue with the import (r), or cancel (c)? [c]: ', 's');
            if ~strcmpi(strtrim(answer), 'r'),
                error('ndi:fun:probe:import:existingNeurons', ...
                    '%s cancelled; the database was not changed.', options.importer);
            end;
        case 'remove',
            if options.verbose, disp(msg); end;
    end;

    % 5) remove each neuron, the documents that depend on it, and any cluster document
    %    left with no neurons

    staleClusterIds = {};
    for i=1:numel(strays),
        eid = strays{i}.id();
        dependents = S.database_search(ndi.query('','depends_on','element_id', eid));
        for j=1:numel(dependents),
            if isfield(dependents{j}.document_properties,'neuron_extracellular'),
                cid = dependents{j}.dependency_value('spike_clusters_id', 'ErrorIfNotFound', 0);
                if ~isempty(cid), staleClusterIds{end+1} = cid; end; %#ok<AGROW>
            end;
        end;
        S.database_rm(cat(1, {strays{i}}, dependents(:)));
        nRemoved = nRemoved + 1;
    end;

    currentIds = cellfun(@(d) d.id(), clusterDocs, 'UniformOutput', false);
    staleClusterIds = setdiff(unique(staleClusterIds), currentIds);
    for i=1:numel(staleClusterIds),
        remaining = S.database_search(ndi.query('','depends_on','spike_clusters_id', staleClusterIds{i}));
        if isempty(remaining),
            S.database_rm(staleClusterIds{i});
        end;
    end;

    if options.verbose,
        disp(sprintf('%s: removed %d earlier neuron element(s) for probe %s.', ...
            options.importer, nRemoved, probe.elementstring()));
    end;

end % resolveExistingNeurons()

function s = describeAction(mode)
    switch mode,
        case 'ask',    s = 'ask whether to remove them';
        case 'remove', s = 'remove them';
        case 'error',  s = 'stop with an error';
    end;
end

function b = isInteractive()
    b = true;
    try
        if batchStartupOptionUsed, b = false; end;
    catch
    end;
    if ~usejava('jvm') && ~isempty(getenv('CI')),
        b = false;
    end;
end
