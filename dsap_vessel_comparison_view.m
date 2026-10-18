function f=dsap_vessel_comparison_view(r)
assert(isfield(r,'vessel_inclusive'),'DSAP:InclusiveUnavailable','此历史结果未保存保留大血管参数；新分析会同时保存两套结果。');
v=r.vessel_inclusive;
f=uifigure('Name','DSAP · 组织 / 保留大血管参数对照','Position',[50 50 1400 900]);
g=uigridlayout(f,[3 1],'RowHeight',{42,'2x','1x'});
uilabel(g,'Text','上排：去除大血管的组织；下排：同一 ROI 保留大血管。相同 AIF、拟合、后处理及有效性条件；每列共用色阶。','WordWrap','on');
p=uipanel(g,'BorderType','none');tiles=tiledlayout(p,2,4,'TileSpacing','compact','Padding','compact');
union=false(size(r.aif_mask));for k=1:numel(v.ROIMasks),union=union|v.ROIMasks{k};end
fields={'CBF','CBV','Tmax','MTT'};ax=gobjects(2,4);
for j=1:4
 a=r.(fields{j});b=v.(fields{j});b(~union)=NaN;
 values=[a(isfinite(a));b(isfinite(b))];limits=[0 1];if ~isempty(values)&&max(values)>min(values),limits=[min(values) max(values)];end
 for row=1:2
  ax(row,j)=nexttile(tiles,(row-1)*4+j);m=a;label='组织';if row==2,m=b;label='保留大血管';end
  image(ax(row,j),repmat(single(.65),[size(m),3]));hold(ax(row,j),'on');im=imagesc(ax(row,j),m);im.AlphaData=isfinite(m);
  axis(ax(row,j),'image','off');ax(row,j).YDir='reverse';colormap(ax(row,j),turbo);clim(ax(row,j),limits);colorbar(ax(row,j));title(ax(row,j),[label ' · ' fields{j}]);
 end
end
tab=uitable(g,'Data',v.Comparison,'RowName',[],'ColumnWidth','auto');
setappdata(f,'DSAPVesselComparison',struct('Axes',ax,'Table',tab,'SnapshotSignature',v.SnapshotSignature));
end
