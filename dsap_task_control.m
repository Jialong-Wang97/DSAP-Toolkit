function value = dsap_task_control(action, varargin)
% Cooperative cancellation for this workflow only. Never terminates MATLAB.
    persistent state
    value=[];
    switch action
        case 'begin'
            if ~isempty(state),error('DSAP:AlreadyRunning','已有 DSAP 分析正在运行。');end
            state=struct('Cancelled',false,'Before',findall(groot,'Type','figure'), ...
                'Figure',[],'Timer',[],'Flag',getenv('DSAP_CANCEL_FILE'), ...
                'ID',char(java.util.UUID.randomUUID()),'InitialFlag',[]);
            state.InitialFlag=flag_stamp(state.Flag);value=state.ID;
            if dsap_workspace_bridge('active'),return;end
            visibility='on';if ~isempty(varargin),visibility=varargin{1};end
            fig=figure('Name','DSAP 分析控制','NumberTitle','off', ...
                'MenuBar','none','ToolBar','none','Position',[30 40 430 120], ...
                'Visible',visibility,'CloseRequestFcn',@(~,~) dsap_task_control('cancel'));
            state.Figure=fig;
            uicontrol(fig,'Style','text','Position',[10 64 410 42], ...
                'String','可随时停止本次分析；已保存的历史结果不受影响。');
            uicontrol(fig,'Style','pushbutton','Position',[105 14 220 40], ...
                'String','停止本次分析','Callback',@(~,~) dsap_task_control('cancel'));
            state.Timer=timer('ExecutionMode','fixedSpacing','Period',0.25, ...
                'BusyMode','drop','TimerFcn',@(~,~) dsap_task_control('poll'));
            start(state.Timer);
        case 'active'
            value=~isempty(state);
        case 'cancelled'
            value=~isempty(state) && state.Cancelled;
        case 'status'
            value=struct('Active',~isempty(state),'Cancelled',false,'ID','');
            if ~isempty(state),value.Cancelled=state.Cancelled;value.ID=state.ID;end
        case 'cancel'
            if isempty(state),return;end
            state.Cancelled=true;
            % Delete only figures created during this run. This releases
            % uiwait/draw ROI callbacks; pre-existing result windows survive.
            figures=findall(groot,'Type','figure');
            for k=1:numel(figures)
                fig=figures(k);
                if ~any(fig==state.Before) && isgraphics(fig)
                    setappdata(fig,'UserCancelled',true);
                    uiresume(fig);
                    set(fig,'CloseRequestFcn','');
                    delete(fig);
                end
            end
        case 'poll'
            if ~isempty(state) && ~state.Cancelled && ...
                    ~isempty(state.Flag) && isfile(state.Flag) && ...
                    ~isequal(flag_stamp(state.Flag),state.InitialFlag)
                dsap_task_control('cancel');
            end
        case 'check'
            if isempty(state),return;end
            dsap_task_control('poll');
            drawnow limitrate;
            if dsap_workspace_bridge('active'),dsap_workspace_bridge('checkpoint');end
            if ~isempty(state) && state.Cancelled
                error('DSAP:Cancelled','用户已停止本次分析。');
            end
        case 'finish'
            if isempty(state),return;end
            previous=state;state=[];
            if ~isempty(previous.Timer) && isvalid(previous.Timer)
                stop(previous.Timer);delete(previous.Timer);
            end
            if isgraphics(previous.Figure)
                set(previous.Figure,'CloseRequestFcn','');delete(previous.Figure);
            end
        otherwise
            error('DSAP:ControlAction','未知的运行控制操作。');
    end
end
function stamp=flag_stamp(file)
stamp=[];if isempty(file)||~isfile(file),return;end
info=dir(file);stamp=[info.datenum info.bytes];
end
