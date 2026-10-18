function dsap_edit_tissue_callback(button,~)
    if ~isgraphics(button)||dsap_task_control('active')||dsap_analysis_session('busy'),return;end
    try
        request=getappdata(button,'SessionToken');state=dsap_analysis_session('get');
        assert(strcmp(request.SessionId,state.Id)&&request.Revision==state.Revision,'DSAP:StaleCallback','旧结果窗口不允许编辑当前患者。');
        r=state.Result;clear state; % Never retain cache volumes across the editor's uiwait.
        if isfield(r,'partition')
            [p,cancelled]=dsap_edit_partition(r.reference_image,r.cranial_limits,r.partition);
            if cancelled,return;end
            request.Partition=p;
        else
            [file,folder]=uigetfile('*.mat','选择包含 timeslice_import 的组织 ROI 文件（AIF 和 union 必须不变）');
            if isequal(file,0),return;end
            input=load(fullfile(folder,file),'timeslice_import');request.TimesliceImport=input.timeslice_import;
        end
        dsap_update_tissue_roi(request);
    catch exception
        if isgraphics(button),errordlg(exception.message,'组织 ROI 更新未完成');end
    end
end
