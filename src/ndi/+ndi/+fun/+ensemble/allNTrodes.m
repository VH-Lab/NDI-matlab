function ensembleElements = allNTrodes(S, options)
% ndi.fun.ensemble.allNTrodes - build ensemble elements for every n-trode in a session
%
% ENSEMBLEELEMENTS = ndi.fun.ensemble.ALLNTRODES(S, ...)
%
% Finds every probe of type 'n-trode' in the ndi.session (or ndi.dataset) S and,
% for each one, builds its ensemble element with an epoch for each of the
% probe's epochs by calling ndi.fun.ensemble.allElement. ENSEMBLEELEMENTS is a
% cell array of the ndi.element.ensemble objects, one per n-trode.
%
% =========================================================================
% INPUTS
% =========================================================================
%   S - an ndi.session or ndi.dataset object.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   IfExists ('skip')  - what to do for an epoch that already has an ensemble:
%                        'skip' (default), 'error', or 'replace'. Passed through
%                        to ndi.fun.ensemble.allElement.
%   Verbose (false)    - print progress messages.
%
% =========================================================================
% OUTPUT
% =========================================================================
%   ENSEMBLEELEMENTS - a cell array of the ndi.element.ensemble objects built,
%                      one per n-trode.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   ens = ndi.fun.ensemble.allNTrodes(S, 'Verbose', true);
%
% See also: ndi.fun.ensemble.allElement, ndi.fun.ensemble.create,
%   ndi.element.ensemble

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

    ensembleElements = {};
    for i = 1:numel(ntrodes)
        if vb
            disp(['ndi.fun.ensemble.allNTrodes: n-trode ' int2str(i) ' of ' ...
                int2str(numel(ntrodes)) '...']);
        end
        ens_i = ndi.fun.ensemble.allElement(S, ntrodes{i}, ...
            'IfExists', options.IfExists, 'Verbose', options.Verbose);
        ensembleElements{end+1} = ens_i; %#ok<AGROW>
    end

    if vb
        disp(['ndi.fun.ensemble.allNTrodes: built ' int2str(numel(ensembleElements)) ...
            ' ensemble element(s).']);
    end

end % allNTrodes()
