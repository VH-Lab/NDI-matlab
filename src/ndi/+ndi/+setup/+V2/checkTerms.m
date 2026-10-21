function [terms, varargout] = checkTerms(fn, options)
%CHECKTERMS Run FN while collecting every unregistered term it writes.
%
%   [TERMS, OUT1, OUT2, ...] = ndi.setup.V2.checkTerms(FN) calls FN() with
%   DID-schema's term registry check turned from an ERROR into a LIST
%   (did2.schema.cache.strictMode('TermRegistry', false) and
%   did2.build.unregisteredTerms collecting, from an empty list), so one run
%   finds every term the registry does not hold instead of stopping at the
%   first (tenet T19, DID-schema V_eta_term_registry_plan.md). TERMS is the
%   list: a struct array with name, node, field, reason and count, one per
%   distinct (name, node, field); empty when every term is registered. OUT1,
%   OUT2, ... are FN's own outputs.
%
%   The registry switch, the collection switch and the list the caller had
%   are put back afterwards, also when FN throws (FN's error is rethrown), so
%   a test or an import that calls this leaves did2.build as it found it.
%
%   Options:
%     'Print'    default true: print "UNREGISTERED TERMS: <n> distinct (name,
%                node, field)" and one line per term -- the line CI reads
%     'Raise'    default false: true throws when TERMS is not empty, AFTER
%                FN has run and the list has been printed, so nothing that
%                comes after the call (a write) runs
%     'ErrorId'  the identifier thrown with 'Raise'
%                (default 'ndi:setup:V2:unregisteredTerms')
%
%   Example (an import's build stages, then its write only if clean):
%       [L, built] = ndi.setup.V2.checkTerms(@() buildEverything(), 'Raise', true);
%       writeEverything(built);
%
%   To register a term, see "Adding terms" in Using_V2.md.
%
%   See also did2.build.unregisteredTerms, ndi.setup.V2.registeredTerm.

arguments
    fn (1,1) function_handle
    options.Print (1,1) logical = true
    options.Raise (1,1) logical = false
    options.ErrorId (1,:) char = 'ndi:setup:V2:unregisteredTerms'
end

before = did2.build.unregisteredTerms();
prevStrict = did2.schema.cache.strictMode('TermRegistry', false);
prevCollect = did2.build.unregisteredTerms('-collect', true);
did2.build.unregisteredTerms('-reset');
restore = onCleanup(@() restoreTerms(prevStrict, prevCollect, before)); %#ok<NASGU>

varargout = cell(1, max(nargout - 1, 0));
if isempty(varargout)
    fn();
else
    [varargout{:}] = fn();
end
terms = did2.build.unregisteredTerms();

if options.Print
    fprintf('\nUNREGISTERED TERMS: %d distinct (name, node, field)\n', numel(terms));
    for k = 1:numel(terms)
        fprintf('  %-40s %-20s %-40s x%d  %s\n', terms(k).name, terms(k).node, ...
            terms(k).field, terms(k).count, terms(k).reason);
    end
end
if options.Raise && ~isempty(terms)
    names = unique({terms.name}, 'stable');
    error(options.ErrorId, ['%d term(s) are not in DID-schema''s term registry (%s); ' ...
        'nothing after this check was run. Correct the name, or register the term ' ...
        '("Adding terms", Using_V2.md).'], numel(terms), strjoin(names, '; '));
end
end

function restoreTerms(prevStrict, prevCollect, before)
% the switches as they were, and the list as the caller had it
arguments
    prevStrict
    prevCollect
    before struct
end
did2.schema.cache.strictMode('TermRegistry', prevStrict);
did2.build.unregisteredTerms('-reset');
for k = 1:numel(before)
    for c = 1:before(k).count
        did2.build.unregisteredTerms('-add', struct('name', before(k).name, ...
            'node', before(k).node), before(k).field, before(k).reason);
    end
end
did2.build.unregisteredTerms('-collect', prevCollect);
end
