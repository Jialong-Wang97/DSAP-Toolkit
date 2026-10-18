function value=dsap_analysis_session(action,varargin)
% One current patient, ordinary struct. Callbacks carry only Id and Revision.
    persistent state busy
    if isempty(busy),busy=false;end
    value=[];
    switch action
        case 'get'
            assert(~isempty(state),'DSAP:NoSession','当前结果没有编辑缓存，请重新完整分析。');value=state;
        case 'active',value=~isempty(state);
        case 'busy',value=busy;
        case 'lock'
            assert(~busy,'DSAP:SessionBusy','已有编辑正在提交。');busy=true;
        case 'unlock',busy=false;
        case 'install'
            assert(isempty(state),'DSAP:SessionExists','必须先释放上一患者缓存。');state=varargin{1};
        case 'publish'
            candidate=varargin{1};id=varargin{2};revision=varargin{3};
            assert(~isempty(state)&&strcmp(state.Id,id)&&state.Revision==revision, ...
                'DSAP:StaleCallback','旧患者或旧 revision 不能提交。');
            assert(strcmp(candidate.UpstreamSignature,state.UpstreamSignature), ...
                'DSAP:UpstreamChanged','R1 上游依赖不得改变。');state=candidate;
        case 'release'
            if ~isempty(varargin)&&(~isempty(state)&&~strcmp(state.Id,varargin{1})),return;end
            if ~isempty(state)
                if isfield(state.View,'Table')&&isgraphics(state.View.Table)
                    h=getappdata(state.View.Table,'DSAPResultControls');
                    if isfield(h,'Edit')&&isgraphics(h.Edit),h.Edit.Enable='off';end
                end
                dsap_session_cache('release',state.Cache);state=[];
            end
            busy=false;
        otherwise,error('DSAP:SessionAction','未知分析状态操作。');
    end
end
