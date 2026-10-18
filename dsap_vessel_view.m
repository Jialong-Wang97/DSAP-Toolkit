function fig=dsap_vessel_view(r,fig,signalTarget)
% Signal/vessel comparison, graphics only; pixel definitions match old display.
    if nargin<2,fig=[];end
    ref=r.reference_image;brain=ref;brain(~r.brain_mask)=0;
    vessel=ref;vessel(~r.large_vessel_mask)=0;tissue=ref;tissue(~r.valid_tissue_mask)=0;
    pictures={ref,brain,vessel,ref,tissue};
    if isempty(fig)||~isgraphics(fig)||~isappdata(fig,'DSAPVesselView')
        if isempty(fig)||~isgraphics(fig)
        fig=figure('Name','信号识别与大血管去除结果','NumberTitle','off','Color','w', ...
            'Position',[20 80 1780 500],'Visible','off');
        end
        separateSignal=nargin>=3&&isgraphics(signalTarget);
        columns=5;if separateSignal,columns=3;end
        layout=tiledlayout(fig,1,columns,'Padding','compact','TileSpacing','compact');
        if separateSignal,signalLayout=tiledlayout(signalTarget,1,2,'Padding','compact','TileSpacing','compact');end
        h.Images=gobjects(1,5);h.Axes=gobjects(1,5);h.Limits=gobjects(3,2);
        names={'原始最大增强 DSA','选定的分析范围','去除的大血管像素','红色：排除的大血管','参与统计的有效显影组织'};
        for k=1:5
            if separateSignal&&k<=2,ax=nexttile(signalLayout);else,ax=nexttile(layout);end
            h.Axes(k)=ax;h.Images(k)=imshow(pictures{k},[],'Parent',ax);hold(ax,'on');title(ax,names{k});dsap_style_axes(ax);
            if k==4
                rgb=zeros([size(ref),3]);rgb(:,:,1)=1;
                h.Overlay=imshow(rgb,'Parent',ax);h.Overlay.AlphaData=.55*double(r.large_vessel_mask);
            end
        end
        for j=1:3
            k=[1 2 4];ax=h.Axes(k(j));xl=xlim(ax);
            h.Limits(j,1)=line(ax,xl,[r.cranial_limits.UpperRow r.cranial_limits.UpperRow], ...
                'Color',[.1 1 1],'LineWidth',1.5,'LineStyle','--');
            h.Limits(j,2)=line(ax,xl,[r.cranial_limits.LowerRow r.cranial_limits.LowerRow], ...
                'Color',[1 .85 .1],'LineWidth',1.5,'LineStyle','--');
        end
        setappdata(fig,'DSAPVesselView',h);
    end
    h=getappdata(fig,'DSAPVesselView');
    for k=1:5
        h.Images(k).CData=pictures{k};h.Images(k).XData=[1 size(ref,2)];h.Images(k).YData=[1 size(ref,1)];
        h.Axes(k).XLim=[.5 size(ref,2)+.5];h.Axes(k).YLim=[.5 size(ref,1)+.5];
        values=pictures{k}(isfinite(pictures{k}));
        if ~isempty(values)&&min(values)<max(values),h.Axes(k).CLim=[min(values) max(values)];else,h.Axes(k).CLim=[0 1];end
    end
    if ~isequal(size(h.Overlay.CData,1),size(ref,1))||~isequal(size(h.Overlay.CData,2),size(ref,2))
        rgb=zeros([size(ref),3]);rgb(:,:,1)=1;h.Overlay.CData=rgb;
    end
    h.Overlay.XData=[1 size(ref,2)];h.Overlay.YData=[1 size(ref,1)];h.Overlay.AlphaData=.55*double(r.large_vessel_mask);
    for j=1:3
        h.Limits(j,1).XData=[.5 size(ref,2)+.5];h.Limits(j,2).XData=[.5 size(ref,2)+.5];
        h.Limits(j,1).YData=[r.cranial_limits.UpperRow r.cranial_limits.UpperRow];
        h.Limits(j,2).YData=[r.cranial_limits.LowerRow r.cranial_limits.LowerRow];
    end
end

