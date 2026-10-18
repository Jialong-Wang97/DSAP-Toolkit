function dsap_export_perfusion_view(folder,fig)
% Export an already prepared view; its data and display limits stay unchanged.
    dsap_task_control('check');
    h=getappdata(fig,'DSAPPerfusionView');
    assert(~isempty(h),'DSAP:InvalidView','需要有效的灌注结果窗口。');
    imwrite(h.Images(2).CData,fullfile(folder,'AIF_ROI_overlay.png'));
    exportgraphics(fig,fullfile(folder,'perfusion_maps.png'),'Resolution',130);
end
