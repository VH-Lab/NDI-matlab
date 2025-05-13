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
%       epochid - A character array (string) representing the unique
%             identifier of the epoch to find.
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
%       element - The NDI element object that contains the epoch
%             specified by EPOCHID.
%                  - If a single matching element is found, it is returned directly.
%                  - If no such element is found, the function will throw an error.
%                  - If multiple elements are found matching the EPOCHID (and optional
%                    filters), a warning is issued, and a cell array of the
%                    matching elements is returned.

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.database.dir'})}
    epochid (1,:) char
    options.name (1,:) char = ''
    options.type (1,:) char = ''
end

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

element = {}; % Initialize as an empty cell array to store found elements
for p = 1:numel(elements)
    
    % Get the epochtable for the current element
    et = elements{p}.epochtable; 
    
    % Iterate through each entry in the epochtable
    for e = 1:numel(et)
        
        % If a match is found, add the current element to the 'element' cell array
        if strcmpi(et(e).epoch_id,epochid)
            element = cat(1,element,elements(p));
        end
    end
end

% Check output size/type and handle accordingly
if iscell(element) & isscalar(element)
    element = element{1};
elseif isempty(element)
    error('EPOCHID2ELEMENTID:NoElementFound','No element was found matching the epochid %s',epochid);
elseif iscell(element) & ~isscalar(element)
    warning('EPOCHID2ELEMENTID:SeveralElementsFound','More than one element was found matching the epochid %s',epochid);
end

end