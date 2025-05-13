function [element] = epochid2element(session,epochid,options)

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.database.dir'})}
    epochid (1,:) char
    options.name (1,:) char = ''
    options.reference (1,:) {mustBeNumeric} = []
    options.type (1,:) char = ''
    options.subject_ID (1,:) char = ''
end

% Get element arguments
elementArgs = {};
argNames = fieldnames(options);
for i = 1:numel(argNames)
    if ~isempty(options.(argNames{i}))
        elementArgs = cat(1,elementArgs,{argNames{i},options.(argNames{i})});
    end
end

% Find probes
probes = session.getprobes(elementArgs{:});

element = {};
for p = 1:numel(probes)
    et = probes{p}.epochtable;
    for e = 1:numel(et)
        if strcmpi(et(e).epoch_id,epochid)
            element = probes{p};
            break
        end
    end
    if ~isempty(element)
        break
    end
end

% Check output size/type
if isempty(element)
    error('EPOCHID2ELEMENTID:NoElementFound','No element was found matching the epochid %s',epochid);
end

end