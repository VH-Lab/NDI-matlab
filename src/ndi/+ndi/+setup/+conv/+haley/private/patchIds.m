function ids = patchIds(subjectIds, plate)
%PATCHIDS The plate's patch subject ids, patch0001, patch0002, ... in order
%   (decision #38: one per row of lawnCenters, numbered in that order).
ids = {};
k = 1;
while isKey(subjectIds, sprintf('%s_patch%04d', plate, k))
    ids{end+1} = subjectIds(sprintf('%s_patch%04d', plate, k)); %#ok<AGROW>
    k = k + 1;
end
end
