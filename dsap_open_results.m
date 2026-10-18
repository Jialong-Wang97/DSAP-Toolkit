function [view,timing]=dsap_open_results(folder,view)
% Restore UI and the Full Export button from Core Save, without reanalysis.
    if nargin<2,view=[];end
    r=dsap_load_result(folder);
    if ~isfield(r,'distribution_summary_table'),r=dsap_attach_roi_distribution(r);end
    r=dsap_roi_artery_analysis(r);
    [view,timing]=dsap_show_results(r,folder,view);
    dsap_result_save_status(view,'saved');
    drawnow;
    status=fullfile(folder,'full_export_status.mat');
    if isfile(status)
        state=load(status);
        if state.full_export_complete
            h=getappdata(view.Table,'DSAPResultControls');
            if isgraphics(h.Status),dsap_workspace_text(h.Status,'核心科研结果和完整图像 / 报告已保存。');end
        end
    end
end
