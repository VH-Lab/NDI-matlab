classdef ScriptedSignedURLSetResult < ndi.cloud.api.implementation.documents.GetSignedURLSetResult
% SCRIPTEDSIGNEDURLSETRESULT - a GetSignedURLSetResult served from a local blob.
%
% Overrides the downloadTo seam so the gzip detection and parsing can be
% exercised without a network. Set blobText to the JSON the server would have
% produced, and gzipped to true to hand it back compressed -- which is what the
% real endpoint does, and what a transport that already inflated it would not.
%
% Set downloadFails to simulate a transport error.

    properties
        blobText = ''
        gzipped = false
        downloadFails = false
    end

    methods
        function this = ScriptedSignedURLSetResult(varargin)
            this@ndi.cloud.api.implementation.documents.GetSignedURLSetResult(varargin{:});
        end
    end

    methods (Access = protected)
        function [ok, answer] = downloadTo(this, localFile)
            if this.downloadFails
                ok = false;
                answer = 'scripted transport failure';
                return
            end

            if this.gzipped
                staging = [tempname '.json'];
                fid = fopen(staging,'w');
                fwrite(fid, this.blobText, 'char');
                fclose(fid);
                names = gzip(staging);
                copyfile(names{1}, localFile, 'f');
                delete(staging);
                delete(names{1});
            else
                fid = fopen(localFile,'w');
                fwrite(fid, this.blobText, 'char');
                fclose(fid);
            end

            ok = true;
            answer = 'scripted';
        end
    end
end
