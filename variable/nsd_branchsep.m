function c = NSD_BRANCHSEP 
% NSD_BRANCHSEP - returns the branch separator character for traversing NSD_VARIABLE_BRANCH objects
%
% C = NSD_BRANCHSEP
%
% Returns the character used to specify subbranches between NSD_VARIABLE_BRANCH objects.
% (The "NSD branch separator" character.)
%
% Right now, this separator is '/' on all platforms.
%
% See also: NSD_VARIABLE_BRANCH, NSD_VARIABLE_BRANCH/PATH2VARBRANCH

c = '/';