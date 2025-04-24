function [missing,epoch_ids] = missingepochs(element1,element2)
%MISSINGEPOCHS Determines if there are epochs in element1 that are not in element2.
%
%   [MISSING, EPOCH_IDS] = MISSINGEPOCHS(ELEMENT1, ELEMENT2) 
%   compares the epoch tables of two input elements and identifies any 
%   epoch ids that are present in the first element but not in the second.
%
%   Inputs:
%       ELEMENT1 - The first element or its associated epoch table.
%       ELEMENT2 - The second element or its associated epoch table.
%
%   Outputs:
%       MISSING    - A logical scalar.  It is TRUE if there are any epochs
%                  present in ELEMENT1's epoch table that are not present in
%                  ELEMENT2's epoch table.  It is FALSE if all epoch IDs
%                  in ELEMENT1 are also in ELEMENT2.
%       EPOCH_IDS  - Contains the 'epoch_id' values (if applicable) that 
%                  are present in ELEMENT1's epoch table but are missing 
%                  from ELEMENT2's epoch table.  If no epochs are missing,
%                   EPOCH_IDS will be an empty cell array.
%
%   See also: NDI.ELEMENT.TIMESERIES, NDI.PROBE.TIMESERIES

% Input validation
arguments
    element1 {mustBeA(element1, {'ndi.element.timeseries','ndi.probe.timeseries','struct'})}
    element2 {mustBeA(element2, {'ndi.element.timeseries','ndi.probe.timeseries','struct'})}
end

% Get epoch tables (if not already the input)
if isa(element1,'struct') & isfield(element1,'epoch_id')
    et1 = element1;
elseif isa(element1,'ndi.element')
    et1 = element1.epochtable;
else
    error('missingEpochs:invalidInput','Element 1 is not a valid input type. Must be an ndi element, probe, or epoch table.')
end

if isa(element2,'struct') & isfield(element2,'epoch_id')
    et2 = element2;
elseif isa(element1,'ndi.element')
    et2 = element2.epochtable;
else
    error('missingEpochs:invalidInput','Element 2 is not a valid input type. Must be an ndi element, probe, or epoch table.')
end

epoch_ids = setdiff({et1.epoch_id},{et2.epoch_id});
missing = ~isempty(epoch_ids);

end