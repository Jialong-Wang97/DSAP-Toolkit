function dsap_patient_session(run_patient,stop_requested)
% Sequential patient loop. Callbacks only request actions, never run analyses.
    if nargin<1,run_patient=@run_interactive_perfusion_remove_large_vessels;end
    if nargin<2,stop_requested=@() isfile(getenv('DSAP_CANCEL_FILE'));end
    before=findall(groot,'Type','figure');
    cleanup=onCleanup(@() close_owned(before)); %#ok<NASGU>
    while ~stop_requested()
        dsap_analysis_session('release');
        output='';failure='';
        try
            output=run_patient();
        catch ME
            failure=ME.message;
            fprintf(2,'%s\n',getReport(ME,'extended','hyperlinks','off'));
        end
        % The workflow's onCleanup must have finished before another begin.
        if dsap_task_control('active')
            error('DSAP:SessionState','上一轮任务尚未释放，不能启动另一位患者。');
        end
        if stop_requested(),return;end
        if ~isempty(failure)
            status=sprintf('本轮分析失败：%s\n可重新选择患者；历史结果未改动。',failure);
        elseif isempty(output)
            status='本轮已取消或未选择影像。可以继续选择下一位患者。';
        else
            status=sprintf('本轮分析已完成并保存：\n%s\n可以继续分析另一位患者或同一患者的其他序列。',output);
        end
        hub=figure('Name','DSAP 连续患者分析','NumberTitle','off','MenuBar','none', ...
            'ToolBar','none','Position',[120 180 780 260], ...
            'CloseRequestFcn',@(f,~) request_action(f,'exit'));
        setappdata(hub,'PatientAction','');
        uicontrol(hub,'Style','text','Units','normalized','Position',[.03 .40 .94 .55], ...
            'HorizontalAlignment','left','FontSize',11,'String',status);
        labels={'下一位患者（关闭已有窗口）','下一位患者（保留结果窗口）','关闭软件'};
        actions={'next-close','next-keep','exit'};
        for k=1:3
            action=actions{k};
            uicontrol(hub,'Style','pushbutton','Units','normalized', ...
                'Position',[.02+(k-1)*.33 .10 .31 .21],'String',labels{k}, ...
                'Tag',action,'Callback',@(f,~) request_action(ancestor(f,'figure'),action));
        end
        % Poll the independent stop flag even while no analysis is running.
        while isgraphics(hub)&&isempty(getappdata(hub,'PatientAction'))&&~stop_requested()
            drawnow;pause(.1);
        end
        if ~isgraphics(hub)||stop_requested(),return;end
        action=getappdata(hub,'PatientAction');
        dsap_safe_delete(hub);
        if strcmp(action,'exit'),return;end
        if strcmp(action,'next-close'),close_owned(before);end
        % No recursive callback or captured image volume survives this point.
    end
end

function request_action(fig,action)
    if ~isgraphics(fig)||~isempty(getappdata(fig,'PatientAction')),return;end
    setappdata(fig,'PatientAction',action);
    set(findall(fig,'Style','pushbutton'),'Enable','off');
end

function close_owned(before)
    dsap_analysis_session('release');
    figures=findall(groot,'Type','figure');
    for fig=figures'
        if ~any(fig==before),dsap_safe_delete(fig);end
    end
end
