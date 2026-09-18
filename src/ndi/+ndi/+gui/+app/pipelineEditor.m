classdef pipelineEditor < ndi.gui.app.sessionApp
% NDI.GUI.APP.PIPELINEEDITOR - launch the graphical NDI pipeline editor
%
%   OBJ = ndi.gui.app.pipelineEditor(SESSION)
%
%   Opens the graphical NDI pipeline editor (ndi.cpipeline.edit) with the
%   ndi.session SESSION pre-linked as the data source. The editor lets the
%   user build and manage pipelines of ndi.calculator objects and run them
%   against the linked session.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor
%   takes the ndi.session as its first argument, so it can be launched from
%   the ndi.gui.navigator "Apps" menu.
%
%   This class is only a thin wrapper. The editor itself, including the
%   window it builds and the pipeline storage it manages, lives in
%   ndi.cpipeline.edit; this app just forwards the session to it.
%
%   See also: ndi.gui.app.sessionApp, ndi.gui.navigator, ndi.cpipeline,
%             ndi.cpipeline.edit

    properties (Constant)
        Name = "Pipeline Editor"   % ndi.gui.app.sessionApp menu label
    end

    properties (Access = private)
        session   % the ndi.session passed to the pipeline editor
    end

    methods
        function obj = pipelineEditor(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session = session;
            % ndi.cpipeline.edit builds and owns its own window; it keeps
            % itself alive via the figure's guidata, so no handle is captured.
            ndi.cpipeline.edit('command', 'new', 'session', obj.session);
        end
    end
end
