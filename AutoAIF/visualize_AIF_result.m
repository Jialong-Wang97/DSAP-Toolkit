function fig=visualize_AIF_result(reference,report,onConfirm,visibility)
% Click candidate center/outline or list, inspect TDC, then explicitly confirm.
if nargin<3,onConfirm=[];end
if nargin<4,visibility='on';end
assert(report.Available,'AutoAIF:Unavailable','%s',report.Reason);
fig=figure('Name','Auto AIF · ICA candidate review','NumberTitle','off','Color','w','Visible',visibility);
ax=axes(fig,'Position',[.06 .34 .43 .60]);imagesc(ax,reference);colormap(ax,gray);axis(ax,'image');hold(ax,'on');
curveAx=axes(fig,'Position',[.57 .44 .39 .47]);chosen=report.SelectedIndex;highlight=[];
for k=1:numel(report.Candidates)
 c=report.Candidates(k);plot(ax,c.CenterlineXY(1),c.CenterlineXY(2),'co','ButtonDownFcn',@(~,~) choose(k));
 paths=bwboundaries(c.Mask);for j=1:numel(paths),plot(ax,paths{j}(:,2),paths{j}(:,1),'c-','ButtonDownFcn',@(~,~) choose(k));end
end
items=arrayfun(@(i) sprintf('#%d ROI%d  score %.3f',i,report.Candidates(report.Ranking.CandidateIndex(i)).ID,report.Ranking.Score(i)),1:height(report.Ranking),'UniformOutput',false);
list=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.55 .28 .41 .07],'String',items,'Callback',@(~,~) choose(report.Ranking.CandidateIndex(list.Value)));
uicontrol(fig,'Style','text','Units','normalized','Position',[.06 .09 .90 .15],'String',report.Reason,'BackgroundColor','w','HorizontalAlignment','left');
button=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.55 .02 .41 .07],'String','确认当前 ROI','Callback',@confirm);
choose(chosen);setappdata(fig,'AutoAIFReview',struct('Choose',@choose,'Confirm',button,'List',list));
 function choose(index)
  chosen=index;c=report.Candidates(index);if ~isempty(highlight),delete(highlight(isgraphics(highlight)));end
  paths=bwboundaries(c.Mask);highlight=gobjects(numel(paths),1);
  for j=1:numel(paths),highlight(j)=plot(ax,paths{j}(:,2),paths{j}(:,1),'y-','LineWidth',2,'HitTest','off');end
  plot(curveAx,report.Time,c.TDC,'LineWidth',1.5);xlabel(curveAx,'Time (s)');ylabel(curveAx,'Enhancement');title(curveAx,sprintf('ROI%d · score %.3f',c.ID,c.Score));
  list.Value=find(report.Ranking.CandidateIndex==index);button.Enable='on';if ~isfinite(c.Score),button.Enable='off';end
 end
 function confirm(~,~)
  if ~isfinite(report.Candidates(chosen).Score),return;end
  report.SelectedIndex=chosen;report.Selected=report.Candidates(chosen);report.Selection='HumanConfirmed';
  if ~isempty(onConfirm),onConfirm(report);end
  if isgraphics(fig),delete(fig);end
 end
end
