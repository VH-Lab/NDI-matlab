function varargout = withMintSource(step, source, fn)
%WITHMINTSOURCE Run FN with the ids it mints derived from SOURCE, not random.
%
%   [OUT1, OUT2, ...] = ndi.migrate.internal.withMintSource(STEP, SOURCE, FN)
%   calls FN() (a function handle taking no arguments) inside a
%   did2.convert.mintId context keyed on SOURCE and STEP, and returns FN's
%   outputs. Every document FN builds without an explicit id -- through
%   did2.build.document (and the builders on top of it: did2.build.statement,
%   did2.build.method, did2.build.directedRelation, ...) or through
%   ndi.migrate.internal.etaShape -- then gets an id that is a pure function of
%   (SOURCE, STEP, the role, its ordinal among the role's ids in this call), so
%   two runs of ndi.migrate.local on the same input mint the same ids.
%
%   WHY. [migration reliability practices] (b) (Jess Haley, 2026-10-26,
%   did-schema docs/plans/did_v2_go_forward_class_audit.md): "a document
%   the migration mints gets an id derived from its v1 source id and its role,
%   so two runs on the same input are identical and can be diffed". DID-matlab
%   #453 (7924c247) and #467 (f7ef92f8) made DID-matlab's batch passes derive
%   their ids this way. NDI's second pass opened no context, so every document
%   it built without an explicit id took did.ido.unique_id(): outside a context
%   did2.convert.mintId is random for a caller that is not in did2.convert.
%
%   SOURCE is what the minted documents are minted FOR: a v1 or migrated
%   document's id (char), a document body (struct; keyed by
%   did2.convert.mintKey: its id, else its canonical JSON), or a key that
%   names a document minted for several sources at once (a strain group's
%   content key, a part's (parent, region, side)). It must not depend on the
%   order documents are read in (NDI-matlab #1235: database order is not data).
%
%   STEP (the calling second-pass step) is part of the key, so two steps that
%   mint for the same source, or a step and pass 1's own mints for that source
%   (did2.convert.v1_to_v2 keys its context on the source id alone), never
%   derive the same id.
%
%   The context is closed when FN returns or throws (an onCleanup), so no
%   context leaks into the rest of the run. An empty SOURCE is an error,
%   ndi:migrate:withMintSource:noSource: a random id would be the only way
%   left, and that is what this function exists to remove.
%
%   See also did2.convert.mintId, did2.convert.mintKey.

arguments
    step (1,:) char
    source
    fn (1,1) function_handle
end

if isstruct(source)
    key = did2.convert.mintKey(source);
else
    key = char(source);
end
if isempty(key)
    error('ndi:migrate:withMintSource:noSource', ...
        ['%s: no source to derive the minted ids from (an empty id, or a body ' ...
         'with neither an id nor a JSON encoding).'], step);
end

depth = did2.convert.mintId('-depth');
did2.convert.mintId('-push', [key '|' step]);
restore = onCleanup(@() did2.convert.mintId('-popto', depth)); %#ok<NASGU>
if nargout == 0
    fn();
else
    [varargout{1:nargout}] = fn();
end
end
