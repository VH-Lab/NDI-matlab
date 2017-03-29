function b = synced(D1, D2)
% SYNCED - Checks if 2 NSD devices are ever synchronized
%
%  B = SYNCHED(D1, D2)
%  return 1 if synced 0 if not synced
%

b = ~isempty( strcmp(D2,D1.sync_list_wts(:,1)) ) ;


% b = 0; % abstract class, never synched with anything
