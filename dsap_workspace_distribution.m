function fig=dsap_workspace_distribution(action,f)
fig=[];buttonKey='DSAPWorkspaceDistributionButton';figureKey='DSAPWorkspaceDistributionFigure';
switch action
 case 'refresh'
  if ~isappdata(f,buttonKey),return;end;b=getappdata(f,buttonKey);if ~isgraphics(b),return;end
  s=getappdata(f,'WorkspaceState');ready=~s.Busy&&s.Activity.ResultsReady&&isappdata(f,'DSAPResultOwnerId');
  if ready,b.Enable='on';else,b.Enable='off';end
 case 'open'
  s=getappdata(f,'WorkspaceState');assert(~s.Busy&&s.Activity.ResultsReady&&isappdata(f,'DSAPResultOwnerId'),'DSAP:DistributionNotReady','请等待当前病例分析完成。');
  if isappdata(f,figureKey),fig=getappdata(f,figureKey);if isgraphics(fig),figure(fig);return;end,end
  owner=dsap_result_owner('get',getappdata(f,'DSAPResultOwnerId'));
  if isappdata(f,'DSAPDistributionLegacyCache')
   r=getappdata(f,'DSAPDistributionLegacyCache');
  elseif dsap_analysis_session('active')
   session=dsap_analysis_session('get');
   if isfield(session.View,'Table')&&isequal(session.View.Table,f),r=session.Result;
   elseif owner.Saved,r=dsap_load_result(owner.Folder);else,r=owner.Result;end
  elseif owner.Saved,r=dsap_load_result(owner.Folder);else,r=owner.Result;end
  if ~isfield(r,'roi_distribution'),r=dsap_add_roi_distribution(r);setappdata(f,'DSAPDistributionLegacyCache',r);end
  fig=dsap_roi_distribution_view(r);setappdata(f,figureKey,fig);
 case 'close'
  if isappdata(f,'DSAPDistributionLegacyCache'),rmappdata(f,'DSAPDistributionLegacyCache');end
  if isappdata(f,figureKey),fig=getappdata(f,figureKey);if isgraphics(fig),delete(fig);end;rmappdata(f,figureKey);end
 otherwise,error('DSAP:DistributionAction','Unknown action.');
end
end
