function fig=dsap_perfusion_view(r,fig)
% Create/update graphics only. No files are written and no parameters computed.
    if nargin<2,fig=[];end
    if isempty(fig)||~isgraphics(fig,'figure')
        fig=figure('Name','有效显影组织灌注参数图','NumberTitle','off','Color','w', ...
            'Position',[40 40 1500 1000],'Visible','off');
        layout=tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');
        h.Axes=gobjects(1,6);h.Images=gobjects(1,6);h.Backgrounds=gobjects(1,4);
        h.Colorbars=gobjects(1,4);
        ax=nexttile(layout);h.Axes(1)=ax;
        h.Images(1)=imshow(r.reference_image,[],'Parent',ax);axis(ax,'image');hold(ax,'on');
        h.Limits=[yline(ax,r.cranial_limits.UpperRow,'c--'),yline(ax,r.cranial_limits.LowerRow,'c--')];
        title(ax,'原始增强投影与上下限');colormap(ax,gray(256));
        ax=nexttile(layout);h.Axes(2)=ax;
        h.Images(2)=imshow(zeros([size(r.reference_image) 3],'single'),'Parent',ax);axis(ax,'image');
        title(ax,'绿：统计组织；红：大血管；青：AIF');
        names={'CBF（相对值）','CBV（相对值）','Tmax (s)','MTT (s)'};
        for k=1:4
            ax=nexttile(layout);h.Axes(k+2)=ax;
            h.Backgrounds(k)=image(ax,repmat(single(.65),[size(r.reference_image),3]));hold(ax,'on');
            h.Images(k+2)=imagesc(ax,zeros(size(r.reference_image)));
            axis(ax,'image','off');set(ax,'YDir','reverse');colormap(ax,turbo);
            h.Colorbars(k)=colorbar(ax);title(ax,[names{k},'；灰色不参与统计']);
        end
        sgtitle(layout,'有效显影组织的参数图：灰色为排除/不可计算，不表示零灌注');
        setappdata(fig,'DSAPPerfusionView',h);
    end
    h=getappdata(fig,'DSAPPerfusionView');
    assert(~isempty(h)&&all(isgraphics(h.Images)),'DSAP:InvalidView','灌注图对象已被删除，请重新打开结果。');
    h.Images(1).CData=r.reference_image;
    set_image_extent(h.Images(1),h.Axes(1),size(r.reference_image));
    % imshow(reference,[]) uses a per-image gray range, independent of map CLim.
    values=r.reference_image(isfinite(r.reference_image));
    if ~isempty(values)&&min(values)<max(values),h.Axes(1).CLim=[min(values) max(values)];else,h.Axes(1).CLim=[0 1];end
    h.Limits(1).Value=r.cranial_limits.UpperRow;h.Limits(2).Value=r.cranial_limits.LowerRow;
    rgb=repmat(single(mat2gray(r.reference_image)),1,1,3);
    masks={r.valid_tissue_mask,r.large_vessel_mask,r.aif_mask};colors=[.1 .9 .25;1 .15 .12;.05 .8 1];
    for k=1:3
        for c=1:3
            plane=rgb(:,:,c);plane(masks{k})=.65*plane(masks{k})+.35*colors(k,c);rgb(:,:,c)=plane;
        end
    end
    h.Images(2).CData=rgb;set_image_extent(h.Images(2),h.Axes(2),size(r.reference_image));
    maps={r.CBF,r.CBV,r.Tmax,r.MTT};
    for k=1:4
        ax=h.Axes(k+2);im=h.Images(k+2);
        if ~isequal(size(h.Backgrounds(k).CData,1),size(r.reference_image,1))|| ...
                ~isequal(size(h.Backgrounds(k).CData,2),size(r.reference_image,2))
            h.Backgrounds(k).CData=repmat(single(.65),[size(r.reference_image),3]);
        end
        set_image_extent(h.Backgrounds(k),ax,size(r.reference_image));
        im.CData=maps{k};im.AlphaData=single(isfinite(maps{k}));set_image_extent(im,ax,size(r.reference_image));
        % Reset auto first, so constant/empty maps cannot inherit an old CLim.
        ax.CLimMode='auto';values=maps{k}(isfinite(maps{k}));
        if ~isempty(values)&&max(values)>min(values),ax.CLim=[min(values),max(values)];end
    end
end

function set_image_extent(im,ax,shape)
    im.XData=[1 shape(2)];im.YData=[1 shape(1)];
    ax.XLim=[.5 shape(2)+.5];ax.YLim=[.5 shape(1)+.5];
end
