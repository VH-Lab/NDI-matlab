function ensemble_docs = allNTrodes(S, options)
% ndi.fun.ensemble.allNTrodes - create ensemble documents for every n-trode in a session
%
% ENSEMBLE_DOCS = ndi.fun.ensemble.ALLNTRODES(S, ...)
%
% Finds every probe of type 'n-trode' in the ndi.session (or ndi.dataset) S and,
% for each one, builds and adds ensemble documents for all of its epochs by
% calling ndi.fun.ensemble.allNTrode. ENSEMBLE_DOCS is a cell array of every
% ensemble ndi.document created across all of the n-trodes.
%
% =========================================================================
% INPUTS
% =========================================================================
%   S - an ndi.session or ndi.dataset object.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   IfExists ('skip')  - what to do for an epoch that already has an ensemble
%                        document: 'skip' (default), 'error', or 'replace'.
%                        Passed through to ndi.fun.ensemble.allNTrode.
%   Verbose (false)    - print progress messages.
%
% =========================================================================
% OUTPUT
% =========================================================================
%   ENSEMBLE_DOCS - a cell array of all the ensemble ndi.documents created and
%                   added to the database across every n-trode.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   docs = ndi.fun.ensemble.allNTrodes(S, 'Verbose', true);
%
% See also: ndi.fun.ensemble.allNTrode, ndi.fun.ensemble.create

    arguments
        S
        options.IfExists (1,:) char {mustBeMember(options.IfExists,{'skip','error','replace'})} = 'skip'
        options.Verbose (1,1) logical = false
    end

    vb = options.Verbose;

    ntrodes = S.getprobes('type','n-trode');
    if vb
        disp(['ndi.fun.ensemble.allNTrodes: found ' int2str(numel(ntrodes)) ...
            ' n-trode probe(s).']);
    end

    ensemble_docs = {};
    for i = 1:numel(ntrodes)
        if vb
            disp(['ndi.fun.ensemble.allNTrodes: n-trode ' int2str(i) ' of ' ...
                int2str(numel(ntrodes)) '...']);
        end
        docs_i = ndi.fun.ensemble.allNTrode(S, ntrodes{i}, ...
            'IfExists', options.IfExists, 'Verbose', options.Verbose);
        ensemble_docs = [ensemble_docs, docs_i(:).']; %#ok<AGROW>
    end

    if vb
        disp(['ndi.fun.ensemble.allNTrodes: created ' int2str(numel(ensemble_docs)) ...
            ' ensemble(s) total across ' int2str(numel(ntrodes)) ' n-trode(s).']);
    end

end % allNTrodes()
