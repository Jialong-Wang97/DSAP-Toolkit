function fig=dsap_curve_view(r,fig,irfTarget)
% Update ROI curves without recreating axes, legends, or existing line objects.
    if nargin<2,fig=[];end
    if isempty(fig)||~isgraphics(fig)||~isappdata(fig,'DSAPCurveView')
        if isempty(fig)||~isgraphics(fig)
        fig=figure('Name','AIF、TIC 与 IRF 曲线','NumberTitle','off','Color','w', ...
            'Position',[120 25 1150 980],'Visible','off');
        end
        separateIRF=nargin>=3&&isgraphics(irfTarget);
        rows=4;if separateIRF,rows=3;end
        layout=tiledlayout(fig,rows,1,'Padding','compact','TileSpacing','compact');
        if separateIRF,irfLayout=tiledlayout(irfTarget,1,1,'Padding','compact','TileSpacing','compact');end
        h.Axes=gobjects(1,4);h.Lines=cell(1,4);h.Legends=gobjects(1,4);h.Names=cell(1,4);
        titles={'原始 DICOM 灰度 TIC（未扣基线、未归一化）','基线校正增强 TIC（重采样与滤波前）', ...
            '等间隔重采样并高斯滤波后的 TIC','ROI 平均脉冲响应函数'};
        ylabels={'DICOM 灰度','增强信号','增强信号','IRF'};
        for k=1:4
            if k==4&&separateIRF,ax=nexttile(irfLayout);else,ax=nexttile(layout);end
            h.Axes(k)=ax;hold(ax,'on');grid(ax,'on');
            title(ax,titles{k});ylabel(ax,ylabels{k});
            if k<3,xlabel(ax,'真实时间 (s)');else,xlabel(ax,'时间 (s)');end
            dsap_style_axes(ax);
        end
        setappdata(fig,'DSAPCurveView',h);
    end
    h=getappdata(fig,'DSAPCurveView');names=r.roi_names(:);
    curves={ [{r.native_original_aif_curve};r.native_original_roi_tics(:)], ...
        [{r.original_aif_curve};r.original_roi_tics(:)], ...
        [{r.aif_curve};r.roi_tics(:)],r.roi_irfs(:)};
    times={r.original_time_seconds,r.original_time_seconds,r.time_seconds,r.time_seconds};
    aif_names={'AIF 原始灰度','AIF','AIF（滤波后）'};
    for k=1:4
        line_names=names;if k<4,line_names=[aif_names(k)';names];end
        old=h.Lines{k};old=old(isgraphics(old));n=numel(curves{k});
        if isempty(old),old=gobjects(0);end
        membership_changed=numel(old)~=n||~isequal(h.Names{k},line_names);
        if numel(old)>n,delete(old(n+1:end));old=old(1:n);end
        for j=1:n
            if j>numel(old),old(j)=plot(h.Axes(k),nan,nan);end %#ok<AGROW>
            if k<4&&j==1,color=[.85 .33 .10];width=2;
            else
                index=j-(k<4);palette=lines(max(7,index));color=palette(index,:);width=1.5;
            end
            % Avoid dirtying unchanged AIF/vessel lines and their legend layout.
            if ~isequaln(old(j).XData(:),times{k}(:)),old(j).XData=times{k};end
            if ~isequaln(old(j).YData(:),curves{k}{j}(:)),old(j).YData=curves{k}{j};end
            if ~isequal(old(j).Color,color),old(j).Color=color;end
            if old(j).LineWidth~=width,old(j).LineWidth=width;end
            if ~strcmp(old(j).DisplayName,line_names{j}),old(j).DisplayName=line_names{j};end
        end
        h.Lines{k}=old;
        if ~isgraphics(h.Legends(k))
            h.Legends(k)=legend(h.Axes(k),old,line_names,'Location','eastoutside','Interpreter','none');
            h.Legends(k).AutoUpdate='off';
        elseif membership_changed
            % legend reuses the existing Legend object when membership changes.
            legend(h.Axes(k),old,line_names,'Location','eastoutside','Interpreter','none');
        end
        h.Names{k}=line_names;
        theme=dsap_theme;h.Legends(k).FontName=theme.Font;h.Legends(k).FontSize=theme.Caption;h.Legends(k).Box='off';
        h.Axes(k).XLimMode='auto';h.Axes(k).YLimMode='auto';
    end
    setappdata(fig,'DSAPCurveView',h);
end

