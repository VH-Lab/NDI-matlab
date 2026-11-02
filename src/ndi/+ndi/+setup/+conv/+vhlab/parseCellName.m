function [name, reference, index, dateString] = parseCellName(cellname)
% PARSECELLNAME - Split a legacy VH Lab cell name into probe name, reference, index and date.
%
% [NAME, REFERENCE, INDEX, DATESTRING] = ndi.setup.conv.vhlab.parseCellName(CELLNAME)
%
% Legacy cells are named cell_NAME_REF_INDEX_YYYY_MM_DD, where NAME is the
% probe name of reference.txt, REF its reference number and INDEX the cell's
% number on that probe. NAME may itself contain underscores (e.g.
% 'cell_extra_t1_001_252_2019_02_26' is probe 'extra_t1', reference 1, cell
% 252), so the name is read from the end: the date, then INDEX, then REF, and
% everything between 'cell_' and REF is NAME. (The legacy cellname2nameref
% reads NAME as the text up to the second underscore, which splits such
% names wrongly.)
%
% NAME and DATESTRING ('YYYY_MM_DD') are char; REFERENCE and INDEX are
% numbers. A name not of this form is an error.
%
% Example:
%   [n, r, i] = ndi.setup.conv.vhlab.parseCellName('cell_extra10_001_251_2018_10_02')
%   % n = 'extra10', r = 1, i = 251
%
% See also: ndi.setup.conv.vhlab.importMeasuredDataCells, ndi.setup.conv.vhlab.validateStacyDirectory

    arguments
        cellname (1,:) char
    end

    tokens = regexp(cellname, '^cell_(.+)_(\d+)_(\d+)_(\d{4}_\d{2}_\d{2})$', 'tokens', 'once');
    if isempty(tokens)
        error('ndi:setup:conv:vhlab:parseCellName:BadName', ...
            'Cell name %s is not of the form cell_NAME_REF_INDEX_YYYY_MM_DD.', cellname);
    end
    name = tokens{1};
    reference = str2double(tokens{2});
    index = str2double(tokens{3});
    dateString = tokens{4};
end
