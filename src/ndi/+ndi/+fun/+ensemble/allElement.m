function ensembleElement = allElement(S, element, options)
% ndi.fun.ensemble.allElement - build an ensemble element for every epoch of an element
%
% ENSEMBLEELEMENT = ndi.fun.ensemble.ALLELEMENT(S, ELEMENT, ...)
%
% Finds (or creates) the ndi.element.ensemble for ELEMENT (usually a probe such
% as an n-trode) in the ndi.session (or ndi.dataset) S, and adds an ensemble for
% each of ELEMENT's epochs (via ndi.fun.ensemble.create). ENSEMBLEELEMENT is the
% ndi.element.ensemble, now carrying an epoch for every epoch of ELEMENT that had
% recorded neurons.
%
% What happens for an epoch that already has an ensemble is controlled by the
% IfExists option.
%
% =========================================================================
% INPUTS
% =========================================================================
%   S       - an ndi.session or ndi.dataset object.
%   ELEMENT - the element to process (usually a probe / n-trode): an
%             ndi.probe/ndi.element object or an element document id string.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   IfExists ('skip')  - what to do for an epoch that already has an ensemble:
%                          'skip'    - leave it and move on (default);
%                          'error'   - raise an error;
%                          'replace' - delete the existing epoch (its map and
%                                      element_epoch documents) and rebuild it.
%   Verbose (false)    - print progress messages (also passed to create).
%
% =========================================================================
% OUTPUT
% =========================================================================
%   ENSEMBLEELEMENT - the ndi.element.ensemble built on ELEMENT.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   ntrodes = S.getprobes('type','n-trode');
%   ens = ndi.fun.ensemble.allElement(S, ntrodes{1}, 'Verbose', true);
%
% See also: ndi.fun.ensemble.allNTrodes, ndi.fun.ensemble.create,
%   ndi.element.ensemble

    arguments
        S
        element
        options.IfExists (1,:) char {mustBeMember(options.IfExists,{'skip','error','replace'})} = 'skip'
        options.Verbose (1,1) logical = false
    end

    vb = options.Verbose;

    probe = local_object(element, S);
    probe_name = local_name(probe);
    ensembleElement = ensembleElementFor(S, probe);

    et = probe.epochtable();
    epochids = {et.epoch_id};
    local_v(vb, ['element ' probe_name ' has ' int2str(numel(epochids)) ' epoch(s).']);

    for i = 1:numel(epochids)
        epochid = epochids{i};

        existing = ndi.fun.ensemble.findExisting(S, ensembleElement, 'epochid', epochid);
        if ~isempty(existing)
            switch options.IfExists
                case 'skip'
                    local_v(vb, ['epoch ' epochid ': an ensemble already exists; skipping.']);
                    continue;
                case 'error'
                    error('ndi:ensemble:allElement:exists', ...
                        ['An ensemble already exists for element %s, epoch %s ' ...
                        '(map document id %s).'], ensembleElement.id(), epochid, existing{1}.id());
                case 'replace'
                    local_v(vb, ['epoch ' epochid ': removing existing ensemble and rebuilding.']);
                    local_remove(S, existing);
            end
        end

        local_v(vb, ['epoch ' epochid ': building ensemble...']);
        ndi.fun.ensemble.create(S, probe, epochid, ...
            'CheckExisting', false, 'SkipIfEmpty', true, ...
            'add_to_database', true, 'Verbose', vb);
    end

    local_v(vb, ['element ' probe_name ': done.']);

end % allElement()

% -------------------------------------------------------------------------

function local_remove(S, mapdocs)
% remove existing ensemble map documents and their element_epoch parents
    for i = 1:numel(mapdocs)
        md = mapdocs{i};
        ee_id = md.dependency_value('element_epoch_id', 'ErrorIfNotFound', 0);
        S.database_rm(md);           % remove the map doc first (it depends on the epoch)
        if ~isempty(ee_id)
            S.database_rm(ee_id);    % remove the element_epoch doc and its binary
        end
    end
end % local_remove()

function obj = local_object(x, S)
    if isa(x, 'ndi.element')
        obj = x;
    elseif ischar(x) || (isstring(x) && isscalar(x))
        obj = ndi.database.fun.ndi_document2ndi_object(char(x), S);
        if isempty(obj)
            error('ndi:ensemble:allElement:badElement', ...
                'Could not load an ndi.element for document id ''%s''.', char(x));
        end
    else
        error('ndi:ensemble:allElement:badElement', ...
            'ELEMENT must be an ndi.probe/ndi.element object or a document id string.');
    end
end % local_object()

function name = local_name(obj)
    try
        name = obj.elementstring();
    catch
        name = obj.id();
    end
end % local_name()

function local_v(verbose, msg)
    if verbose
        disp(['ndi.fun.ensemble.allElement: ' msg]);
    end
end % local_v()
