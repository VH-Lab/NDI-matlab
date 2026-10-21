function [q, matches, info] = methodQuery(search, patterns)
%METHODQUERY Find statements by method, whether inline or a `method` document.
%
%   [Q, MATCHES, INFO] = ndi.v2.methodQuery(SEARCH, PATTERNS) is the method
%   filter for statement searches. did-schema #88 (V_eta_method_plan.md, Jess
%   Haley 2026-10-21): a statement names its method by the inline block
%   `interaction.method: {term, parameters}` OR by a `method_id` edge to a
%   standalone `method` document -- never both. A method filter matches
%   either: a statement whose inline `interaction.method.term` matches one of
%   PATTERNS, or whose `method_id` names a `method` document whose
%   `method.term` does (ndi.v2.methodOf reads both the same way).
%
%   SEARCH is a function handle taking an ndi.query and returning the
%   documents (e.g. @(x) S.database_search(x)); it is used once, to find the
%   matching `method` documents. PATTERNS is a pattern or a cell array of
%   patterns as ndi.v2.matchTerm takes them (a name ignoring case or a node;
%   '*' a wildcard).
%
%   Q is an ndi.query that narrows a statement search to those two kinds
%   (the inline term query, ndi.v2.termQuery, OR `depends_on method_id` any
%   matching method document), or [] when nothing can be sent to the
%   database (no text patterns; a wildcard without did2's `wildcard`
%   operator; more than 200 matching method documents). Like termQuery's,
%   its answer is a superset: recheck each document with MATCHES, a function
%   handle taking a document's properties and returning true when its
%   inline term or its `method_id` target matches.
%
%   INFO: methodDocuments (the `method` documents read), matched (those
%   whose term matched).
%
%   See also ndi.v2.methodOf, ndi.v2.searchStatements, ndi.statement.search.

arguments
    search function_handle
    patterns
end

if ischar(patterns) || isstring(patterns), patterns = cellstr(patterns); end
patterns = patterns(cellfun(@ischar, patterns));
q = [];
info = struct('methodDocuments', 0, 'matched', 0);
if isempty(patterns)
    matches = @(p) true;
    return;
end

% the standalone method documents whose term matches
mq = ndi.v2.isaQuery('method');
t = ndi.v2.termQuery('method.term', patterns);
if ~isempty(t), mq = mq & t; end
mdocs = search(mq);
ids = {};
for i = 1:numel(mdocs)
    p = ndi.v2.props(mdocs{i});
    if ~isfield(p, 'method') || ~isstruct(p.method) || isempty(p.method), continue; end
    b = p.method(1);
    if isfield(b, 'term') && ndi.v2.matchTerm(b.term, patterns)
        ids{end+1} = char(p.base.id); %#ok<AGROW>
    end
end
ids = unique(ids);
info.methodDocuments = numel(mdocs);
info.matched = numel(ids);

matches = @(p) inlineMatches(p, patterns) || any(ismember(ndi.v2.edgeIds(p, 'method_id'), ids));

inline = ndi.v2.termQuery('interaction.method.term', patterns);
if isempty(inline) || numel(ids) > 200
    return;     % the recheck does it all
end
q = inline;
if ~isempty(ids)
    q = q | ndi.v2.anyOf(cellfun(@(i) ndi.query('', 'depends_on', 'method_id', i), ids, ...
        'UniformOutput', false));
end
end

function tf = inlineMatches(p, patterns)
% does the inline method's term (`interaction.method.term`) match?
arguments
    p
    patterns
end
tf = false;
b = ndi.v2.blockOf(p, 'interaction', 'method', []);
if isstruct(b) && ~isempty(b) && isfield(b, 'term')
    tf = ndi.v2.matchTerm(b(1).term, patterns);
end
end
