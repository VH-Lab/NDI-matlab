function b= NSD_synced(D1, D2)
% NSD_SYNCED - Checks if 2 devices are ever synchronized
%
%  B = NSD_SYNCHED(D1, D2)
%
%

if isa(D2,'NSD_stimtimes_example'),
	b = 1;
else,
	b = 0;
end;
