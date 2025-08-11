function [element] = epochid2element(session,epochid,options)
% EPOCHID2ELEMENT - Find an NDI element given an epochid
%
%   ELEMENT = EPOCHID2ELEMENT(SESSION, EPOCHID) searches through all 
%   elements within the session to find the element that contains the 
%   specified EPOCHID in its epochtable.
%
%   ELEMENT = EPOCHID2ELEMENT(SESSION, EPOCHID, 'NAME', NAME_VALUE, 'TYPE', TYPE_VALUE)
%   allows for optional filtering of elements by name and/or type before
%   searching for the EPOCHID. This can be useful for speeding up the search
%   in sessions with many elements or for resolving ambiguity if the same
%   EPOCHID might exist in elements of different types or names.
%
%   Input Arguments:
%       session  - An NDI session object.
%       epochid - A character vector or a cell array of character vectors 
%                  representing the unique identifier(s) of the epoch(s) to find.
%
%   Optional Name-Value Pair Arguments:
%       name     - A character array (string). If provided, the search is
%                  restricted to elements with this name. Defaults to ''
%                  (no name restriction).
%       type     - A character array (string). If provided, the search is
%                  restricted to elements of this type. Defaults to ''
%                  (no type restriction).
%
%   Output Arguments:
%       element - A cell array of NDI element object(s) associated that 
%             contain the epoch(s) specified by EPOCHID.

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.database.dir'})}
    epochid (1,:) {mustBeA(epochid,{'char','str','cell'})}
    options.name (1,:) char = ''
    options.type (1,:) char = ''
end

% Add progress bar
progressbar = ndi.gui.component.ProgressBarWindow('','GrabMostRecent',true);
pid = did.ido.unique_id();
progressbar.addBar('Label','Finding elements from epoch ids','Tag',pid,'Auto',true);

% Get element arguments for filtering if options are provided
elementArgs = {};
argNames = fieldnames(options);
for i = 1:numel(argNames)
    if ~isempty(options.(argNames{i}))
        elementArgs = cat(1,elementArgs,{['element.',argNames{i}],options.(argNames{i})});
    end
end

% Get elements from the session
elements = session.getelements(elementArgs{:});

element = cell(size(epochid));
for p = 1:numel(elements)
    
    % Get the epochtable for the current element
    et = elements{p}.epochtable; 
    
    % Iterate through each entry in the epochtable
    for e = 1:numel(et)
        
        % Check if underlying epochs match any epoch id(s)
        epochInd = strcmpi(epochid,et(e).epoch_id);
        
        if any(epochInd)
            element{epochInd} = elements(p);
        end
    end

    % Update the progressbar
    if mod(p,10)==0
        progressbar.updateBar(pid,p/numel(elements));
    end
end
progressbar.updateBar(pid,1); % Update the bar's progress

% Check output size/type
missingID = cellfun(@isempty,element);
if any(missingID)
    warning('EPOCHID2ELEMENT:NoElementFound','No element was found matching the epoch id(s): \n %s',...
        strjoin(epochid(missingID),'\n'));
end

end