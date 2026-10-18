function seconds=dsap_update_critical_view(view,r,folder,visibility)
% No auxiliary graphics, export, or scientific operations on this path.
    started=tic;h=getappdata(view.Perfusion,'DSAPCriticalView');
    maps={r.CBF,r.CBV,r.Tmax,r.MTT};
    for k=1:4
        h.Images(k).CData=maps{k};h.Images(k).AlphaData=single(isfinite(maps{k}));
        h.Axes(k).CLimMode='auto';v=maps{k}(isfinite(maps{k}));
        if ~isempty(v)&&max(v)>min(v),h.Axes(k).CLim=[min(v) max(v)];end
    end
    controls=getappdata(view.Table,'DSAPResultControls');parameters=dsap_result_parameter_table(r);data=table2cell(parameters);
    for k=1:numel(data)
        if isstring(data{k})||iscategorical(data{k}),data{k}=char(data{k});end
    end
    set(controls.Table,'Data',data,'ColumnName',parameters.Properties.VariableNames);
    setappdata(controls.Export,'OutputDirectory',folder);
    dsap_workspace_text(controls.Status,'计算完成；关键结果可操作，正在准备辅助视图。');
    if isfield(view,'Workspace'),dsap_workspace_bridge('critical',r);end
    view.Perfusion.Visible=visibility;
    setappdata(view.Perfusion,'DSAPCriticalReady',true);
    drawnow;
    if isfield(view,'Workspace'),dsap_workspace_bridge('critical_visible');end
    seconds=toc(started);
end
