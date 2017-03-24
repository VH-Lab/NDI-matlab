function b= sampleAPI_synced(D1, D2)
% SAMPLEAPI_SYNCED - Checks if 2 devices are ever synchronized
%
%  B = SAMPLEAPI_SYNCHED(D1, D2)
%
%

if isa(D2,'sAPI_stimtimes_example'),
	b = 1;
else
	b = 0;
end;
