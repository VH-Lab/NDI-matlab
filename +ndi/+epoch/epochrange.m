function [er,et,t0_t1] = epochrange(ndi_epochset_obj, clocktype, firstEpoch, lastEpoch)
% EPOCHRANGE - return a range of epochs between a first and last epoch
%
% [ER,ET,T0_T1] = EPOCHRANGE(NDI_EPOCHSET_OBJ, CLOCKTYPE, FIRSTEPOCH, LASTEPOCH)
%
% Examine the NDI_EPOCHSET_OBJ and return the epochs between FIRSTEPOCH
% and LASTEPOCH. FIRSTEPOCH and LASTEPOCH can be number or epoch_ids. Only
% epochs with a CLOCKTYPE are considered matches.
%
% NDI_EPOCHSET_OBJ must be of type ndi.epoch.epochset.
%
% ER is a cell array of epoch_ids spanning FIRSTEPOCH and LASTEPOCH, inclusive.
%
% ET is the epochtable of the NDI_EPOCHSET_OBJ.
% T0_T1 (Nx2) are values of T0 and T1 for the given CLOCKTYPE for each epoch.
% 
%
% Example:
%  er = ndi.epoch.epochrange(myprobe,2,4);
%

arguments
    ndi_epochset_obj (1,1) ndi.epoch.epochset
    clocktype (1,1) ndi.time.clocktype
    firstEpoch {ndi.validators.mustBeEpochInput(firstEpoch)}
    lastEpoch {ndi.validators.mustBeEpochInput(lastEpoch)}
end

et = ndi_epochset_obj.epochtable();

if isstring(firstEpoch) | ischar(firstEpoch)
    firstEpoch = char(firstEpoch);
    index1 = find(strcmp(firstEpoch,{et.epoch_id}));
else
    index1 = firstEpoch;
end

if isstring(lastEpoch) | ischar(lastEpoch)
    lastEpoch = char(lastEpoch);
    index2 = find(strcmp(lastEpoch,{et.epoch_id}));
else
    index2 = lastEpoch;
end

assert(~isempty(index1),['Could not find first epoch ' firstEpoch '.']);
assert(~isempty(index2),['Could not find last epoch ' lastEpoch '.']);

assert(index1<=index2,['firstEpoch must be before or equal to lastEpoch']);

assert( 1<=index1&index1<=numel(et) ,...
    ['firstEpoch position must be in 1..' int2str(numel(et)) '.']);

assert( 1<=index2&index2<=numel(et) ,...
    ['lastEpoch position must be in 1..' int2str(numel(et)) '.']);

er = {};

t0_t1 = NaN(index2-index1+1,2);

for i=index1:index2
    er{end+1} = et(i).epoch_id;
    clockIndex = find(cellfun(@(x) eq(x,clocktype), et(i).epoch_clock));
    if isempty(clockIndex),
       error(['Epoch ' er{end} ' lacks clocktype ' clocktype.type '.']);
    end
    t0_t1(i,1) = et(i).t0_t1{clockIndex}(1);
    t0_t1(i,2) = et(i).t0_t1{clockIndex}(2);
end


