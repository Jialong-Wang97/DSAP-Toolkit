function varargout=dsap_result_owner(action,varargin)
% Retain recoverable scientific results independently of optional editing cache.
    persistent owners
    if isempty(owners),owners=containers.Map('KeyType','char','ValueType','any');end
    switch action
        case 'create'
            id=char(java.util.UUID.randomUUID());r=varargin{1};
            state=struct('Id',id,'Result',r,'Snapshot',r.roi_snapshot,'Folder',varargin{2}, ...
                'Saved',false,'Saving',false,'Error','','View',struct());
            owners(id)=state;varargout={id};
        case 'get'
            assert(isKey(owners,varargin{1}),'DSAP:StaleResult','Result owner no longer exists.');
            varargout={owners(varargin{1})};
        case 'attach'
            id=varargin{1};s=owners(id);s.View=varargin{2};owners(id)=s;
            setappdata(s.View.Table,'DSAPResultOwnerId',id);
            h=getappdata(s.View.Table,'DSAPResultControls');
            if ~isfield(h,'Retry')||~isgraphics(h.Retry)
                h.Retry=uicontrol(s.View.Table,'Style','pushbutton','Units','normalized', ...
                    'Position',[.57 .018 .18 .04],'String','重试核心保存','Visible','off', ...
                    'Callback',@(~,~) retry(id));
                setappdata(s.View.Table,'DSAPResultControls',h);
            end
            if ~isfield(s.View,'Workspace')
                s.View.Table.CloseRequestFcn=@(~,~) request_close(id);
            end
        case 'update'
            id=varargin{1};s=owners(id);r=varargin{2};
            assert(~s.Saved&&~s.Saving&&strcmp(s.Snapshot.FullSignature,r.roi_snapshot.FullSignature), ...
                'DSAP:StaleResult','Cannot replace another frozen result.');
            s.Result=r;owners(id)=s;
        case 'save'
            id=varargin{1};s=owners(id);
            assert(~s.Saving,'DSAP:SaveBusy','Core Save already running.');
            if s.Saved,varargout={true,''};return;end
            s.Saving=true;owners(id)=s;
            save_function=@dsap_save_core;if numel(varargin)>1,save_function=varargin{2};end
            if isfield(s.View,'Workspace')
                dispatch=getappdata(s.View.Table,'DSAPWorkspaceDispatch');
                dispatch('activity','Saving','Saving','Results ready · Saving core result…');
            end
            try
                dsap_validate_roi_snapshot(s.Snapshot);
                save_function(s.Folder,s.Result);
                s.Saved=true;s.Error='';s.Result=[];s.Snapshot=[];
                dsap_result_save_status(s.View,'saved');
            catch e
                if isfield(s.View,'Workspace'),dsap_workspace_log_error(s.View.Table,e,'Core Save');end
                s.Error=e.message;dsap_result_save_status(s.View,'failed',s.Error);
            end
            s.Saving=false;owners(id)=s;
            if isfield(s.View,'Table')&&isgraphics(s.View.Table)
                h=getappdata(s.View.Table,'DSAPResultControls');
                if isfield(h,'Retry'),h.Retry.Visible=onoff(~s.Saved);end
            end
            drawnow;varargout={s.Saved,s.Error};
        case 'release'
            id=varargin{1};s=owners(id);
            assert(s.Saved,'DSAP:UnsavedResult','Cannot silently release the only unsaved result.');
            remove(owners,id);
        case 'discard'
            id=varargin{1};s=owners(id);
            assert(numel(varargin)>1&&isequal(varargin{2},true)&&~s.Saving, ...
                'DSAP:DiscardConfirmation','Discard requires an explicit confirmed decision.');
            remove(owners,id);
        otherwise,error('DSAP:ResultOwnerAction','Unknown action.');
    end
end
function retry(id)
    dsap_result_owner('save',id);
end
function workspace_close(id)
    s=dsap_result_owner('get',id);
    state=getappdata(s.View.Table,'WorkspaceState');
    h=getappdata(s.View.Table,'DSAPResultControls');
    if state.Busy
        dsap_task_control('cancel');uiresume(s.View.Table);
        dsap_workspace_text(h.Status,'已请求安全取消；任务结束后可关闭。');return;
    end
    if ~s.Saved
        dsap_workspace_text(h.Status,'结果尚未保存：请点击重试 Core Save。完整结果仍保留，不能静默关闭。');
        dispatch=getappdata(s.View.Table,'DSAPWorkspaceDispatch');dispatch('navigate',6);drawnow;return;
    end
    delete(s.View.Table);dsap_result_owner('release',id);
end
function request_close(id)
    s=dsap_result_owner('get',id);
    if ~s.Saved
        choice=questdlg('核心结果尚未保存；完整结果仍保留在内存。','未保存结果', ...
            '重试保存','保持窗口','保持窗口');
        if strcmp(choice,'重试保存'),dsap_result_owner('save',id);end
        return;
    end
    delete(s.View.Table);dsap_result_owner('release',id);
end
function value=onoff(flag)
    value='off';if flag,value='on';end
end
