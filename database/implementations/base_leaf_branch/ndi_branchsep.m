function c = NDI_BRANCHSEP 
% NDI_BRANCHSEP - returns the branch separator character for traversing NDI_VARIABLE_BRANCH objects
%
% C = NDI_BRANCHSEP
%
% Returns the character used to specify subbranches between NDI_VARIABLE_BRANCH objects.
% (The "NDI branch separator" character.)
%
% Right now, this separator is '/' on all platforms.
%
% See also: NDI_VARIABLE_BRANCH, NDI_VARIABLE_BRANCH/PATH2VARBRANCH

c = '/';
