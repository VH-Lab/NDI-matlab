function T = summary(x)
%SUMMARY A table of subjects, entities or statements, one row each.
%
%   T = ndi.summary(X): X is what ndi.subject.search, ndi.entity.search,
%   ndi.statement.search or ndi.subject/statements returns -- a cell array,
%   any mix of classes -- or an array, or one object.
%     subjects and other entities  ndi.entity/summary: name, kind, id, and
%                                  for subjects type, local_identifier and a
%                                  column per asserted variable (inherited)
%     statements                   ndi.statement/summary: subject, kind,
%                                  class, variable, method, value, unit,
%                                  start, end, stated_on, via, id
%   Entities and statements make different tables, so X holds one or the
%   other. For one object, x.summary() does the same.
%
%   ws = ndi.subject.search(ds, 'type', 'organism', 'strain', 'N2');
%   ndi.summary(ws)                          % one row per worm
%   ndi.summary(statements([ws{:}]))         % everything about them
%
%   See also ndi.entity/summary, ndi.statement/summary.

if ~iscell(x)
    x = num2cell(x);
end
x = reshape(x, 1, []);
isEnt = cellfun(@(e) isa(e, 'ndi.entity'), x);
isSt = cellfun(@(e) isa(e, 'ndi.statement'), x);
if ~all(isEnt | isSt)
    bad = find(~(isEnt | isSt), 1);
    error('ndi:summary:what', 'ndi.summary takes entities or statements (item %d is a %s).', ...
        bad, class(x{bad}));
end
if any(isEnt) && any(isSt)
    error('ndi:summary:mixed', ...
        'Entities and statements make different tables: summarise them separately.');
end
if all(isSt) && ~isempty(x)
    T = ndi.statement.summaryOf(x);
else
    T = ndi.entity.summaryOf(x);
end
end
