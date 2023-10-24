function startupFcn(app, varargin)
            
    if nargin >= 2
        vlt.data.assign(varargin{:})
        app.Session = session;
        app.FilePath = filepath;
    end

    % app.setFigureMinSize()
    app.UITableAuthor.SelectionType = "row";
    app.UITableAuthor.DoubleClickedFcn = @app.onDoubleClickInAuthorTable;
    app.UITableSubject.SelectionType = "row";

    app.SubjectData = ndi.database.metadata_app.class.SubjectData;
    n = 3;
    for i = 1:n
        app.SubjectData.addItem();
    end
    app.SubjectData.assignName();
    data = app.SubjectData.formatTable();
    app.UITableSubject.Data = struct2table(data, 'AsArray', true);

    %check if app has a Session field
    if isfield(app, 'Session')
        probeData = ndi.database.metadata_app.fun.loadProbes(app.Session);
        probeTableData = probeData.formtaTable();
    end

    probeTableData = {'Probe1' 'Double-click to select' 'Incomplete'; ...
        'Probe2' 'Double-click to select' 'Incomplete';  ...
        'Probe3' 'Double-click to select' 'Incomplete'};
    app.UITableProbe.Data = probeTableData;
    app.UITableProbe.ColumnFormat = {[] {'Electrode' 'Electrode Array', 'Pipette'} []};
  
    % app.loadDatasetInformation()
end