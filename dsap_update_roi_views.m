function view=dsap_update_roi_views(r,view,folder)
% R1 updates only table/curves/partition; unchanged maps/vessels are untouched.
    assert(isgraphics(view.Table)&&isgraphics(view.Curves),'DSAP:ViewClosed','编辑结果窗口已关闭，请重新完整分析。');
    h=getappdata(view.Table,'DSAPResultControls');parameters=dsap_result_parameter_table(r);data=table2cell(parameters);
    for row=1:size(data,1)
        for col=1:size(data,2)
            if isstring(data{row,col})||iscategorical(data{row,col}),data{row,col}=char(data{row,col});end
        end
    end
    h.Table.Data=data;h.Table.ColumnName=parameters.Properties.VariableNames;setappdata(h.Export,'OutputDirectory',folder);
    view.Curves=dsap_curve_view(r,view.Curves);
    if isfield(r,'partition'),view.Partition=dsap_partition_view(r,view.Partition);end
    dsap_result_save_status(view,'pending');
    drawnow; % Sole R1 render boundary: includes every required graphics update.
end
