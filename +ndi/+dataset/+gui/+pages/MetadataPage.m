classdef MetadataPage < ndi.gui.window.wizard.abstract.Page


    properties (Constant)
        Name = "Metadata"
        Title = "Metadata"
        Description = "Specify how to extract metadata from foldernames"
    end

    
    methods
        function obj = MetadataPage()

        end
    end

    methods (Access = protected)
        function onPageEntered(obj)
            % Subclasses may override
        end

        function onPageExited(obj)
            % Subclasses may override
        end
    end


end