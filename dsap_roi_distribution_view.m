function f=dsap_roi_distribution_view(r)
% Compact downstream viewer. Dropdown changes reuse precomputed metrics.
assert(isfield(r,'roi_distribution'),'DSAP:DistributionMissing','No cached distribution available.');
f=uifigure('Name','ROI Distribution / Heterogeneity','Position',[90 70 1160 800]);
g=uigridlayout(f,[3 2],'RowHeight',{40,'1x',60},'ColumnWidth',{400,'1x'});
bar=uigridlayout(g,[1 4],'ColumnWidth',{'1x',110,145,150},'Padding',0);bar.Layout.Column=[1 2];
labels=arrayfun(@(k)sprintf('%d · %s',k,r.roi_names{k}),1:numel(r.roi_names),'UniformOutput',false);
roi=uidropdown(bar,'Items',labels,'ItemsData',1:numel(labels),'ValueChangedFcn',@render);
param=uidropdown(bar,'Items',{'CBF','CBV','MTT','Tmax'},'ValueChangedFcn',@render);
mode=uidropdown(bar,'Items',{'Raw','Normalized'},'ValueChangedFcn',@render);
uibutton(bar,'Text','导出 CSV / MAT / Excel','ButtonPushedFcn',@export_data);
tab=uitable(g,'ColumnName',{'Metric','Value'},'ColumnWidth',{265,105},'RowName',[]);tab.Layout.Row=2;tab.Layout.Column=1;
right=uigridlayout(g,[2 1],'RowHeight',{'1x','1x'});right.Layout.Row=2;right.Layout.Column=2;
hax=uiaxes(right);sax=uiaxes(right);note=uilabel(g,'WordWrap','on');note.Layout.Row=3;note.Layout.Column=[1 2];
setappdata(f,'DSAPDistributionView',struct('ROI',roi,'Parameter',param,'Mode',mode,'Table',tab,'Histogram',hax,'Spatial',sax,'Render',@render,'Note',note));
render();
 function render(varargin)
  k=roi.Value;p=param.Value;m=r.roi_distribution(k).(p).Distribution;
  [map,mask]=dsap_distribution_roi_input(r,k,p);[x,valid,q,z,range]=dsap_distribution_pixels(map,mask,r.DistributionAnalysisOptions);
  fields=fieldnames(m);data=cell(0,2);
  for j=1:numel(fields)
   v=m.(fields{j});if (isnumeric(v)||islogical(v))&&isscalar(v),data(end+1,:)={fields{j},double(v)};end %#ok<AGROW>
  end
  flags=fieldnames(m.QCFlags);active=flags(structfun(@logical,m.QCFlags));
  tab.Data=data;cla(hax);cla(sax);marks=[m.P10 m.P50 m.P90];
  if strcmp(mode.Value,'Normalized')
   histogram(hax,z,linspace(0,1,r.DistributionAnalysisOptions.HistogramBins+1));
   if range(2)>range(1),marks=min(1,max(0,(marks-range(1))/(range(2)-range(1))));else,marks(:)=0;end
   preview=double(q);title(sax,'Quantized input (outside ROI transparent)');xlabel(hax,'P01–P99 robust normalized intensity');
  else
   histogram(hax,x,r.DistributionAnalysisOptions.HistogramBins);preview=double(map);title(sax,'Existing parameter map + valid ROI boundary');xlabel(hax,p);
  end
  hold(hax,'on');names={'P10','Median','P90'};
  for j=1:3,if isfinite(marks(j)),xline(hax,marks(j),'--',names{j});end,end
  hold(hax,'off');ylabel(hax,'Valid pixel count');title(hax,sprintf('%s | N=%d',r.roi_names{k},m.NValid),'Interpreter','none');
  preview(~valid)=NaN;im=imagesc(sax,preview);im.AlphaData=valid;axis(sax,'image');colormap(sax,parula);colorbar(sax);
  hold(sax,'on');if any(valid,'all'),contour(sax,0:size(valid,2)+1,0:size(valid,1)+1,double(padarray(valid,[1 1],false)),[.5 .5],'w');end;hold(sax,'off');
  if isempty(active),qc='无';else,qc=strjoin(active,', ');end
  note.Text=['QC: ' qc '。分布与纹理仅使用现有有效像素；Normalized 不改变原始灌注值。'];
 end
 function export_data(~,~)
  folder=uigetdir(pwd,'选择 Distribution 导出目录');if isequal(folder,0),return;end
  try
   destination=tempname(folder);dsap_export_roi_distribution(destination,r,true);note.Text=['已导出：' destination];
  catch e,note.Text=['导出失败：' e.message];end
 end
end
