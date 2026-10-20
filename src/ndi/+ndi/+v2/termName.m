function n = termName(t)
%TERMNAME The name of a term ({node, name}, {name} or an ndi.term); its node when it has no name.
arguments
    t
end

n = '';
if isempty(t), return; end
if iscell(t), t = t{1}; end
if isa(t, 'ndi.term')
    n = char(t(1));
    return;
end
if isstruct(t)
    t = t(1);
    if isfield(t, 'name') && ~isempty(t.name)
        n = char(t.name);
    elseif isfield(t, 'node')
        n = char(t.node);
    end
elseif ischar(t) || isstring(t)
    n = char(t);
end
end
