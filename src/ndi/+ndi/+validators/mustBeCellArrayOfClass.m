function mustBeCellArrayOfClass(c, className)
% MUSTBECELLARRAYOFCLASS - validation function that checks if all elements of a cell array are of a certain class
%
    if ~iscell(c)
        error('Input must be a cell array.');
    end
    for i=1:numel(c)
        if ~isa(c{i}, className)
            error(['All elements of the cell array must be of class ' className '.']);
        end
    end
end
