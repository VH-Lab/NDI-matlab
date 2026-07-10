function ensemble_docs = allElement(S, element, options)
% ndi.fun.ensemble.allElement - create ensemble documents for every epoch of an element
%
% ENSEMBLE_DOCS = ndi.fun.ensemble.ALLELEMENT(S, ELEMENT, ...)
%
% For the ELEMENT in the ndi.session (or ndi.dataset) S (usually a probe such as
% an n-trode), finds every epoch of ELEMENT and, for each one, builds and adds
% to the database an 'ensemble' ndi.document describing the spiking neurons
% recorded on ELEMENT in that epoch (see ndi.fun.ensemble.create).
% ENSEMBLE_DOCS is a cell array of the ensemble documents that were created.
%
% What happens for an epoch that already has an ensemble document (matched by
% ELEMENT and epoch) is controlled by the IfExists option.
%
% =========================================================================
% INPUTS
% =========================================================================
%   S       - an ndi.session or ndi.dataset object.
%   ELEMENT - the element to process (usually a probe / n-trode): an
%             ndi.probe/ndi.element object or an element document id string. Its
%             epochs are read from its epochtable, and its spiking neurons are
%             the elements that have it as their underlying element.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   IfExists ('skip')  - what to do for an epoch that already has an ensemble
%                        document for ELEMENT:
%                          'skip'    - leave the existing document and move on
%                                      (default);
%                          'error'   - raise an error;
%                          'replace' - delete the existing document(s) and
%                                      build a new one.
%   Verbose (false)    - print progress messages (also passed to
%                        ndi.fun.ensemble.create).
%
% =========================================================================
% OUTPUT
% =========================================================================
%   ENSEMBLE_DOCS - a cell array of the ensemble ndi.documents created and
%                   added to the database by this call (epochs that were
%                   skipped, or that had no recorded neurons, are not
%                   included).
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   ntrodes = S.getprobes('type','n-trode');
%   docs = ndi.fun.ensemble.allElement(S, ntrodes{1}, 'Verbose', true);
%
% See also: ndi.fun.ensemble.allNTrodes, ndi.fun.ensemble.create

    arguments
        S
        element
        options.IfExists (1,:) char {mustBeMember(options.IfExists,{'skip','error','replace'})} = 'skip'
        options.Verbose (1,1) logical = false
    end

    vb = options.Verbose;

    element_obj = local_object(element, S);
    element_id = element_obj.id();
    element_name = local_name(element_obj, element_id);

    et = element_obj.epochtable();
    epochids = {et.epoch_id};
    local_v(vb, ['element ' element_name ' has ' int2str(numel(epochids)) ' epoch(s).']);

    ensemble_docs = {};
    for i = 1:numel(epochids)
        epochid = epochids{i};

        existing = S.database_search( ...
            ndi.query('','isa','ensemble','') & ...
            ndi.query('','depends_on','element_id', element_id) & ...
            ndi.query('epochid.epochid','exact_string', epochid, ''));

        if ~isempty(existing)
            switch options.IfExists
                case 'skip'
                    local_v(vb, ['epoch ' epochid ': an ensemble already exists; skipping.']);
                    continue;
                case 'error'
                    error('ndi:ensemble:allElement:exists', ...
                        ['An ensemble document already exists for element %s, ' ...
                        'epoch %s (document id %s).'], element_id, epochid, existing{1}.id());
                case 'replace'
                    local_v(vb, ['epoch ' epochid ': removing ' int2str(numel(existing)) ...
                        ' existing ensemble(s) and rebuilding.']);
                    S.database_rm(existing);
            end
        end

        local_v(vb, ['epoch ' epochid ': building ensemble...']);
        doc = ndi.fun.ensemble.create(S, element_obj, epochid, ...
            'add_to_database', true, 'CheckExisting', false, ...
            'SkipIfEmpty', true, 'Verbose', vb);
        if ~isempty(doc)
            ensemble_docs{end+1} = doc; %#ok<AGROW>
        end
    end

    local_v(vb, ['element ' element_name ': created ' int2str(numel(ensemble_docs)) ...
        ' ensemble(s).']);

end % allElement()

% -------------------------------------------------------------------------

function obj = local_object(x, S)
% return an object (with id() and epochtable()) from an object or a doc id
    if ischar(x) || (isstring(x) && isscalar(x))
        obj = ndi.database.fun.ndi_document2ndi_object(char(x), S);
        if isempty(obj)
            error('ndi:ensemble:allElement:badElement', ...
                'Could not load an ndi.element for document id ''%s''.', char(x));
        end
    elseif isobject(x)
        obj = x;
    else
        error('ndi:ensemble:allElement:badElement', ...
            'ELEMENT must be an ndi.probe/ndi.element object or a document id string.');
    end
end % local_object()

function name = local_name(obj, fallback)
    try
        name = obj.elementstring();
    catch
        name = fallback;
    end
end % local_name()

function local_v(verbose, msg)
    if verbose
        disp(['ndi.fun.ensemble.allElement: ' msg]);
    end
end % local_v()
