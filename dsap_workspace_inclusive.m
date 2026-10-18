function fig=dsap_workspace_inclusive(action,f)
fig=[];key='DSAPWorkspaceInclusiveFigure';button='DSAPWorkspaceInclusiveButton';
switch action
 case 'refresh'
  if ~isappdata(f,button),return;end;b=getappdata(f,button);if ~isgraphics(b),return;end
  s=getappdata(f,'WorkspaceState');b.Enable='off';if ~s.Busy&&s.Activity.ResultsReady&&isappdata(f,'DSAPResultOwnerId'),b.Enable='on';end
 case 'open'
  s=getappdata(f,'WorkspaceState');assert(~s.Busy&&s.Activity.ResultsReady,'DSAP:InclusiveBusy','请等待分析完成。');
  if isappdata(f,key),fig=getappdata(f,key);if isgraphics(fig),figure(fig);return;end,end
  owner=dsap_result_owner('get',getappdata(f,'DSAPResultOwnerId'));
  r=[];
  if dsap_analysis_session('active')
   session=dsap_analysis_session('get');if isfield(session.View,'Table')&&isequal(session.View.Table,f),r=session.Result;end
  end
  if isempty(r),if owner.Saved,r=dsap_load_result(owner.Folder);else,r=owner.Result;end,end
  fig=dsap_vessel_comparison_view(r);setappdata(f,key,fig);
 case 'close'
  if isappdata(f,key),fig=getappdata(f,key);if isgraphics(fig),delete(fig);end;rmappdata(f,key);end
 otherwise,error('DSAP:InclusiveAction','Unknown action.');
end
end
