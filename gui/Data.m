classdef Data < handle
    properties
        documents;
        window;
        info;
    end
    methods
        function obj = Data()
            %Create window
            obj.window = axes('position', [1/18 1/12 2/3 2/3], ...
                              'XLim', [0 24], 'YLim', [0 16]);
            axis off;
            hold on;
            rectangle(obj.window, 'position', [0 0 24 16], ...
                      'facecolor', [1 1 1]);
            
            %Create info
            obj.info = axes('position', [7/9 1/12 1/6 2/3], ...
                            'Xlim', [0 6], 'YLim', [0 16]);
            axis off;
            hold on;
            rectangle(obj.info, 'position', [0 0 6 16], 'facecolor', [1 1 1]);
            
            %Create document list
            obj.documents = [];
            
            %Create drop down
            
        end
        
        function addDoc(obj, docs)
            for i=1:numel(docs)
                obj.documents(numel(obj.documents)+1) = string(docs{i});
            end
        end
    end
end