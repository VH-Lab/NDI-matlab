function postsetup(S)
% POSTSETUP - does all post-setup operations for Marder lab data
%
% POSTSETUP(S)
%
% 1) Generates epochprobemaps for ABF data
% 2) Checks that the probes are available in S
% 3) Generates the metadata with ndi.setup.conv.marder.pretemptable(S)
%  

% Step 1:

ndi.setup.conv.marder.abfprobetable2probemap(S)

% Step 2:

S.cache.clear();
p = S.getprobes()

% Step 3:

ndi.setup.conv.marder.preptemptable(S)

