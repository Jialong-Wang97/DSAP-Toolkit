function dsap_result_save_status(view,state,message)
    if nargin<3,message='';end
    if ~isfield(view,'Table')||~isgraphics(view.Table),return;end
    h=getappdata(view.Table,'DSAPResultControls');
    if isempty(h)||~isgraphics(h.Status)||~isgraphics(h.Export),return;end
    switch state
        case 'pending'
            dsap_workspace_text(h.Status,'计算完成；核心科研结果正在保存。完整图像 / QC 可稍后手动导出。');h.Export.Enable='off';
        case 'saved'
            dsap_workspace_text(h.Status,'核心科研结果已保存；PNG / QC / 拆分文件尚未完整导出。');h.Export.Enable='on';
        case 'failed'
            dsap_workspace_text(h.Status,['核心保存失败：' message]);h.Export.Enable='off';
    end
    if isfield(view,'Workspace')
        dispatch=getappdata(view.Table,'DSAPWorkspaceDispatch');dispatch('status',state);
    end
    % Rendering belongs to the caller: queued map/legend work is not status work.
end
