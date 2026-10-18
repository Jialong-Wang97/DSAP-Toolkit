function dsap_full_export_callback(button,~)
% User-triggered synchronous export; never re-enter an ongoing analysis.
    if ~isgraphics(button)||strcmp(button.Enable,'off'),return;end
    fig=ancestor(button,'figure');h=getappdata(fig,'DSAPResultControls');
    if dsap_task_control('active')||isequal(getappdata(groot,'DSAPFullExportBusy'),true)
        h.Status.String='当前有分析或导出正在运行，请待其完成后再导出。';return;
    end
    folder=getappdata(button,'OutputDirectory');button.Enable='off';
    cleanup=onCleanup(@() enable(button)); %#ok<NASGU>
    h.Status.String='正在完整导出；核心科研结果已保存。';drawnow;
    try
        dsap_full_export(folder);
        if isgraphics(h.Status),h.Status.String=['完整导出已完成：' folder];end
    catch exception
        if isgraphics(h.Status)
            h.Status.String=['完整导出未完成，核心结果保留，可重试：' exception.message];
        end
        if ~strcmp(exception.identifier,'DSAP:Cancelled'),warning('DSAP:ExportFailed','%s',exception.message);end
    end
    drawnow;
end
function enable(button)
    if isgraphics(button),button.Enable='on';end
end
